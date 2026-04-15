import express from "express";
import { chromium, type Cookie } from "playwright";
import { provision, deprovision } from "./platforms/notion.js";

const app = express();
app.use(express.json());

const PORT = parseInt(process.env.PORT || "3000", 10);
const NOTION_BASE = "https://www.notion.so";

interface RawCookie {
  name: string;
  value: string;
  domain: string;
  path: string;
  sameSite?: string | null;
  secure?: boolean;
  httpOnly?: boolean;
  expirationDate?: number;
  expires?: number;
  hostOnly?: boolean;
  session?: boolean;
  storeId?: string | null;
}

function normalizeCookies(raw: RawCookie[]): Cookie[] {
  return raw.map((c) => {
    let sameSite: "Strict" | "Lax" | "None" = "Lax";
    if (c.sameSite === "strict") sameSite = "Strict";
    else if (c.sameSite === "lax") sameSite = "Lax";
    else if (c.sameSite === "no_restriction" || c.sameSite === "None") sameSite = "None";

    return {
      name: c.name,
      value: c.value,
      domain: c.domain,
      path: c.path || "/",
      secure: c.secure ?? true,
      httpOnly: c.httpOnly ?? false,
      sameSite,
      expires: c.expirationDate ?? c.expires ?? -1,
    };
  });
}

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/validate-session", async (req, res) => {
  const { cookies } = req.body as { cookies: RawCookie[] };

  if (!cookies || !Array.isArray(cookies)) {
    res.status(400).json({ success: false, error: "cookies array required" });
    return;
  }

  const normalizedCookies = normalizeCookies(cookies);

  let browser = null;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    await context.addCookies(normalizedCookies);

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
