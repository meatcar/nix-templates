import json
import subprocess


def test_bun_executes_javascript():
    result = subprocess.run(
        ["bun", "--eval", "console.log(JSON.stringify([7, 2, 5].toSorted()))"],
        check=True,
        capture_output=True,
        text=True,
    )
    assert json.loads(result.stdout) == [2, 5, 7]
