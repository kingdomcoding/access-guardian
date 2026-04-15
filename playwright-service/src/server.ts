import express from "express";
import { chromium, type Cookie } from "playwright";
import { provision, deprovision } from "./platforms/notion.js";

const app = express();
app.use(express.json());

const PORT = parseInt(process.env.PORT || "3000", 10);
const NOTION_BASE = "https://www.notion.so";

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/validate-session", async (req, res) => {
  const { cookies } = req.body as { cookies: Cookie[] };

  if (!cookies || !Array.isArray(cookies)) {
    res.status(400).json({ success: false, error: "cookies array required" });
    return;
  }

  let browser = null;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    await context.addCookies(cookies);

    const page = await context.newPage();
    await page.goto(NOTION_BASE, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3000);

    const currentUrl = page.url();
    if (currentUrl.includes("/login") || currentUrl.includes("/signin")) {
      res.json({ success: false, error: "Cookies are invalid or expired. Log into Notion and try again." });
      return;
    }

    const sessionPath = "/app/data/notion.json";
    await context.storageState({ path: sessionPath });
    console.log(`[ValidateSession] Session saved at ${sessionPath}`);

    res.json({ success: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[ValidateSession] Failed: ${message}`);
    res.json({ success: false, error: message });
  } finally {
    if (browser) await browser.close();
  }
});

app.post("/provision", async (req, res) => {
  const { email } = req.body as { email: string };

  if (!email) {
    res.status(400).json({ success: false, error: "email required", error_type: "permanent", steps: [] });
    return;
  }

  const result = await provision(email);
  res.json(result);
});

app.post("/deprovision", async (req, res) => {
  const { email } = req.body as { email: string };

  if (!email) {
    res.status(400).json({ success: false, error: "email required", error_type: "permanent", steps: [] });
    return;
  }

  const result = await deprovision(email);
  res.json(result);
});

app.listen(PORT, () => {
  console.log(`Playwright service running on port ${PORT}`);
});
