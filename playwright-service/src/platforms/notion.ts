import { chromium, type Browser } from "playwright";
import fs from "fs";

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

const NOTION_BASE = "https://www.notion.so";
const DEFAULT_SESSION_PATH = "/app/data/notion.json";

export async function provision(
  email: string,
  sessionPath: string = DEFAULT_SESSION_PATH
): Promise<Result> {
  const steps: Step[] = [];
  let browser: Browser | null = null;

  try {
    steps.push({ step: 1, name: "load_session", status: "running" });
    if (!fs.existsSync(sessionPath)) {
      steps[steps.length - 1].status = "failed";
      return {
        success: false,
        error: "No session found. Complete setup at /integrations/setup first.",
        error_type: "permanent",
        steps,
      };
    }
    steps[steps.length - 1].status = "done";

    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ storageState: sessionPath });
    const page = await context.newPage();

    steps.push({ step: 2, name: "navigate_members", status: "running" });
    await page.goto(`${NOTION_BASE}/settings/members`, {
      waitUntil: "domcontentloaded",
      timeout: 30000,
    });
    await page.waitForTimeout(3000);

    if (page.url().includes("/login") || page.url().includes("/signin")) {
      steps[steps.length - 1].status = "failed";
      return {
        success: false,
        error: "Session expired. Re-authenticate at /integrations/setup.",
        error_type: "permanent",
        steps,
      };
    }
    steps[steps.length - 1].status = "done";

    steps.push({ step: 3, name: "invite_member", status: "running" });
    const addButton = page.locator(
      'button:has-text("Add members"), [role="button"]:has-text("Add")'
    );
    await addButton.first().click({ timeout: 5000 });
    await page.waitForTimeout(1000);

    const emailInput = page.locator(
      'input[placeholder*="email" i], input[type="email"]'
    );
    await emailInput.first().fill(email);
    await page.waitForTimeout(500);

    const inviteButton = page.locator(
      'button:has-text("Invite"), [role="button"]:has-text("Invite")'
    );
    await inviteButton.first().click({ timeout: 5000 });
    await page.waitForTimeout(2000);
    steps[steps.length - 1].status = "done";

    return { success: true, external_account_id: `notion:${email}`, steps };
  } catch (err) {
    const lastStep = steps[steps.length - 1];
    if (lastStep) lastStep.status = "failed";
    const message = err instanceof Error ? err.message : String(err);
    const isTimeout = message.includes("Timeout") || message.includes("timeout");
    return {
      success: false,
      error: message,
      error_type: isTimeout ? "transient" : "permanent",
      steps,
    };
  } finally {
    if (browser) await browser.close();
  }
}

export async function deprovision(
  email: string,
  sessionPath: string = DEFAULT_SESSION_PATH
): Promise<Result> {
  const steps: Step[] = [];
  let browser: Browser | null = null;

  try {
    steps.push({ step: 1, name: "load_session", status: "running" });
    if (!fs.existsSync(sessionPath)) {
      steps[steps.length - 1].status = "failed";
      return {
        success: false,
        error: "No session found. Complete setup at /integrations/setup first.",
        error_type: "permanent",
        steps,
      };
    }
    steps[steps.length - 1].status = "done";

    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ storageState: sessionPath });
    const page = await context.newPage();

    steps.push({ step: 2, name: "navigate_members", status: "running" });
    await page.goto(`${NOTION_BASE}/settings/members`, {
      waitUntil: "domcontentloaded",
      timeout: 30000,
    });
    await page.waitForTimeout(3000);

    if (page.url().includes("/login") || page.url().includes("/signin")) {
      steps[steps.length - 1].status = "failed";
      return {
        success: false,
        error: "Session expired. Re-authenticate at /integrations/setup.",
        error_type: "permanent",
        steps,
      };
    }
    steps[steps.length - 1].status = "done";

    steps.push({ step: 3, name: "find_and_remove", status: "running" });
    const memberRow = page.locator(`text="${email}"`).first();
    await memberRow.hover();

    const moreButton = page.locator('[aria-label="More"], button:has-text("...")').first();
    await moreButton.click({ timeout: 5000 });
    await page.waitForTimeout(500);

    const removeOption = page.locator(
      'text="Remove from workspace", [role="menuitem"]:has-text("Remove")'
    ).first();
    await removeOption.click({ timeout: 5000 });
    await page.waitForTimeout(1000);

    const confirmButton = page.locator(
      'button:has-text("Remove"), button:has-text("Confirm")'
    ).first();
    await confirmButton.click({ timeout: 5000 });
    await page.waitForTimeout(2000);
    steps[steps.length - 1].status = "done";

    return { success: true, external_account_id: `notion:${email}`, steps };
  } catch (err) {
    const lastStep = steps[steps.length - 1];
    if (lastStep) lastStep.status = "failed";
    const message = err instanceof Error ? err.message : String(err);
    const isTimeout = message.includes("Timeout") || message.includes("timeout");
    return {
      success: false,
      error: message,
      error_type: isTimeout ? "transient" : "permanent",
      steps,
    };
  } finally {
    if (browser) await browser.close();
  }
}
