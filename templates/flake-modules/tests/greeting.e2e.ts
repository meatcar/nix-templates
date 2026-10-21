import { expect, test } from "@playwright/test";

import { main } from "../src/index";

test("renders the sample greeting", async ({ page }) => {
  await page.setContent(`<h1>${main()}</h1>`);
  await expect(page.getByRole("heading", { name: "Hello, Bun!", exact: true })).toBeVisible();
});
