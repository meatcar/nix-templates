import yaml


def test_proxy_values_are_normalized_on_every_activation(sandbox_project):
    sandbox = sandbox_project
    taskfile_path = sandbox.project / ".agents/Taskfile.yml"
    taskfile = yaml.safe_load(taskfile_path.read_text())
    record = 'printf "%s|%s|%s|%s\\n" "${HTTP_PROXY-}" "${http_proxy-}" "${HTTPS_PROXY-}" "${https_proxy-}" >> proxies'
    for name in ("before_nix", "setup_auth", "resume_auth", "ready", "setup_cleanup"):
        taskfile["tasks"][name]["cmds"] = [record]
    taskfile_path.write_text(yaml.safe_dump(taskfile))
    sandbox.run("direnv", "allow", ".")
    cases = [
        ("setup", {}, "", ""),
        (
            "setup",
            {"npm_config_https_proxy": "https://first.invalid:8443"},
            "https://first.invalid:8443",
            "https://first.invalid:8443",
        ),
        (
            "resume",
            {"npm_config_https_proxy": "https://second.invalid:9443"},
            "https://second.invalid:9443",
            "https://second.invalid:9443",
        ),
        (
            "resume",
            {
                "http_proxy": "http://plain.invalid:8080",
                "https_proxy": "https://secure.invalid:8444",
            },
            "http://plain.invalid:8080",
            "https://secure.invalid:8444",
        ),
        (
            "resume",
            {
                "HTTP_PROXY": "http://upper.invalid",
                "HTTPS_PROXY": "https://upper.invalid",
                "http_proxy": "http://ignored.invalid",
                "https_proxy": "https://ignored.invalid",
            },
            "http://upper.invalid",
            "https://upper.invalid",
        ),
        (
            "resume",
            {"npm_config_http_proxy": "http://http-only.invalid"},
            "http://http-only.invalid",
            "http://http-only.invalid",
        ),
    ]
    for phase, environment, http, https in cases:
        (sandbox.project / "proxies").write_text("")
        sandbox.run(f".agents/{phase}", env=environment)
        expected = "|".join([http, http, https, https])
        assert (sandbox.project / "proxies").read_text().splitlines() == [expected] * (
            4 if phase == "setup" else 3
        )
