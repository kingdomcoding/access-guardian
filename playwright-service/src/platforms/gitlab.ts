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

const SESSION_PATH = "/app/data/gitlab.json";
const GITLAB_BASE = "https://gitlab.com";

function membersUrl(groupPath: string): string {
  return `${GITLAB_BASE}/groups/${groupPath}/-/group_members`;
}

export async function provision(
  email: string,
  groupPath: string
): Promise<Result> {
  const steps: Step[] = [];
  let browser: Browser | null = null;

  try {
    steps.push({ step: 1, name: "load_session", status: "running" });
    if (!fs.existsSync(SESSION_PATH)) {
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
    const context = await browser.newContext({ storageState: SESSION_PATH });
    const page = await context.newPage();

    steps.push({ step: 2, name: "navigate_members", status: "running" });
    const url = membersUrl(groupPath);
    console.log(`[Provision] Navigating to ${url}`);
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(2000);

    if (page.url().includes("/users/sign_in")) {
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

    await page.locator('button:has-text("Invite members")').click({ timeout: 5000 });
    await page.waitForTimeout(1000);

    const emailInput = page.locator('[data-testid="members-token-select-input"]')
      .or(page.locator('input[placeholder*="Search for members"]'))
      .or(page.locator('.gl-token-selector input'));
    await emailInput.first().fill(email);
    await page.waitForTimeout(1000);

    await page.keyboard.press("Enter");
    await page.waitForTimeout(500);

    await page.locator('[data-testid="invite-modal-submit"]')
      .or(page.locator('button:has-text("Invite")').last())
      .click({ timeout: 5000 });
    await page.waitForTimeout(2000);

    steps[steps.length - 1].status = "done";

    return { success: true, external_account_id: `gitlab:${email}`, steps };
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
  groupPath: string
): Promise<Result> {
  const steps: Step[] = [];
  let browser: Browser | null = null;

  try {
    steps.push({ step: 1, name: "load_session", status: "running" });
    if (!fs.existsSync(SESSION_PATH)) {
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
    const context = await browser.newContext({ storageState: SESSION_PATH });
    const page = await context.newPage();

    steps.push({ step: 2, name: "navigate_members", status: "running" });
    await page.goto(membersUrl(groupPath), { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(2000);

    if (page.url().includes("/users/sign_in")) {
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

    const memberRow = page.locator(`tr:has-text("${email}")`).first();
    const actionsButton = memberRow.locator('button[aria-label="Actions"]')
      .or(memberRow.locator('[data-testid="user-action-dropdown"]'));
    await actionsButton.click({ timeout: 5000 });
    await page.waitForTimeout(500);

    await page.locator('button:has-text("Remove member")').click({ timeout: 5000 });
    await page.waitForTimeout(500);

    await page.locator('[data-testid="remove-member-modal-button"]')
      .or(page.locator('button:has-text("Remove member")').last())
      .click({ timeout: 5000 });
    await page.waitForTimeout(2000);

    steps[steps.length - 1].status = "done";

    return { success: true, external_account_id: `gitlab:${email}`, steps };
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
