import express from "express";
import { chromium, type Cookie } from "playwright";
import { provision, deprovision } from "./platforms/notion.js";

const app = express();
app.use(express.json());

const PORT = parseInt(process.env.PORT || "3000", 10);

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/validate-session", async (req, res) => {
  const { cookies, workspace_url } = req.body as {
    cookies: Cookie[];
    workspace_url: string;
  };

  if (!cookies || !Array.isArray(cookies) || !workspace_url) {
    res.status(400).json({ success: false, error: "cookies array and workspace_url required" });
    return;
  }

  let browser = null;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    await context.addCookies(cookies);

    const page = await context.newPage();
    await page.goto(workspace_url, { waitUntil: "networkidle", timeout: 20000 });

    const currentUrl = page.url();
    if (currentUrl.includes("/login") || currentUrl.includes("/signin")) {
      res.json({ success: false, error: "Cookies are invalid or expired. Log into Notion and try again." });
      return;
    }

    const sessionPath = "/app/data/notion.json";
    await context.storageState({ path: sessionPath });
    console.log(`[ValidateSession] Session saved at ${sessionPath}`);

    res.json({ success: true });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[ValidateSession] Failed: ${message}`);
    res.json({ success: false, error: message });
  } finally {
    if (browser) await browser.close();
  }
});

app.post("/provision", async (req, res) => {
  const { email, workspace_url } = req.body as { email: string; workspace_url: string };

  if (!email || !workspace_url) {
    res.status(400).json({ success: false, error: "email and workspace_url required", error_type: "permanent", steps: [] });
    return;
  }

  const result = await provision(email, workspace_url);
  res.json(result);
});

app.post("/deprovision", async (req, res) => {
  const { email, workspace_url } = req.body as { email: string; workspace_url: string };

  if (!email || !workspace_url) {
    res.status(400).json({ success: false, error: "email and workspace_url required", error_type: "permanent", steps: [] });
    return;
  }

  const result = await deprovision(email, workspace_url);
  res.json(result);
});

app.listen(PORT, () => {
  console.log(`Playwright service running on port ${PORT}`);
});
