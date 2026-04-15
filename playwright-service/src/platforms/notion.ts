import { chromium, Browser, Page } from "playwright";

interface Step {
  step: number;
  name: string;
  status: string;
}

export interface Result {
  success: boolean;
  external_account_id?: string;
  error?: string;
  error_type?: "permanent" | "transient";
  steps: Step[];
}

interface Credentials {
  email: string;
  password: string;
}

async function login(page: Page, creds: Credentials, steps: Step[]): Promise<void> {
  steps.push({ step: 1, name: "navigate_login", status: "running" });
  await page.goto("https://www.notion.so/login", { waitUntil: "networkidle", timeout: 15000 });
  steps[steps.length - 1].status = "done";

  steps.push({ step: 2, name: "enter_email", status: "running" });
  await page.fill('input[type="email"]', creds.email);
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForTimeout(2000);
  steps[steps.length - 1].status = "done";

  steps.push({ step: 3, name: "enter_password", status: "running" });
  await page.fill('input[type="password"]', creds.password);
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForNavigation({ waitUntil: "networkidle", timeout: 15000 });
  steps[steps.length - 1].status = "done";
}

export async function provision(
  email: string,
  workspaceUrl: string,
  creds: Credentials
): Promise<Result> {
  const steps: Step[] = [];
  let browser: Browser | null = null;

  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    await login(page, creds, steps);

    steps.push({ step: 4, name: "navigate_members", status: "running" });
    await page.goto(`${workspaceUrl}/settings/members`, { waitUntil: "networkidle", timeout: 15000 });
    steps[steps.length - 1].status = "done";

    steps.push({ step: 5, name: "invite_member", status: "running" });
    const addButton = page.locator('button:has-text("Add members"), [role="button"]:has-text("Add")');
    await addButton.first().click({ timeout: 5000 });
    await page.waitForTimeout(1000);

    const emailInput = page.locator('input[placeholder*="email" i], input[type="email"]');
    await emailInput.first().fill(email);
    await page.waitForTimeout(500);

    const inviteButton = page.locator('button:has-text("Invite"), [role="button"]:has-text("Invite")');
    await inviteButton.first().click({ timeout: 5000 });
    await page.waitForTimeout(2000);
    steps[steps.length - 1].status = "done";

    return { success: true, external_account_id: `notion:${email}`, steps };
  } catch (err: unknown) {
    const lastStep = steps[steps.length - 1];
    if (lastStep) lastStep.status = "failed";
    const message = err instanceof Error ? err.message : String(err);
    const isTimeout = message.includes("Timeout") || message.includes("timeout");
    return { success: false, error: message, error_type: isTimeout ? "transient" : "permanent", steps };
  } finally {
    if (browser) await browser.close();
  }
}

export async function deprovision(
  email: string,
  workspaceUrl: string,
  creds: Credentials
): Promise<Result> {
  const steps: Step[] = [];
  let browser: Browser | null = null;

  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    await login(page, creds, steps);

    steps.push({ step: 4, name: "navigate_members", status: "running" });
    await page.goto(`${workspaceUrl}/settings/members`, { waitUntil: "networkidle", timeout: 15000 });
    steps[steps.length - 1].status = "done";

    steps.push({ step: 5, name: "find_and_remove", status: "running" });
    const memberRow = page.locator(`text="${email}"`).first();
    await memberRow.hover();

    const moreButton = page.locator('[aria-label="More"], button:has-text("...")').first();
    await moreButton.click({ timeout: 5000 });
    await page.waitForTimeout(500);

    const removeOption = page.locator('text="Remove from workspace", [role="menuitem"]:has-text("Remove")').first();
    await removeOption.click({ timeout: 5000 });
    await page.waitForTimeout(1000);

    const confirmButton = page.locator('button:has-text("Remove"), button:has-text("Confirm")').first();
    await confirmButton.click({ timeout: 5000 });
    await page.waitForTimeout(2000);
    steps[steps.length - 1].status = "done";

    return { success: true, external_account_id: `notion:${email}`, steps };
  } catch (err: unknown) {
    const lastStep = steps[steps.length - 1];
    if (lastStep) lastStep.status = "failed";
    const message = err instanceof Error ? err.message : String(err);
    const isTimeout = message.includes("Timeout") || message.includes("timeout");
    return { success: false, error: message, error_type: isTimeout ? "transient" : "permanent", steps };
  } finally {
    if (browser) await browser.close();
  }
}
