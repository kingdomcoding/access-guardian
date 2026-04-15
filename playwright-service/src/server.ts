import express from "express";
import { provision, deprovision } from "./platforms/notion.js";

const app = express();
app.use(express.json());

const PORT = parseInt(process.env.PORT || "3000", 10);

function getCredentials() {
  return {
    email: process.env.NOTION_EMAIL || "",
    password: process.env.NOTION_PASSWORD || "",
  };
}

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/provision", async (req, res) => {
  const { email, workspace_url } = req.body;
  const creds = getCredentials();

  if (!email || !workspace_url) {
    res.status(400).json({ success: false, error: "email and workspace_url required", error_type: "permanent", steps: [] });
    return;
  }

  const result = await provision(email, workspace_url, creds);
  res.json(result);
});

app.post("/deprovision", async (req, res) => {
  const { email, workspace_url } = req.body;
  const creds = getCredentials();

  if (!email || !workspace_url) {
    res.status(400).json({ success: false, error: "email and workspace_url required", error_type: "permanent", steps: [] });
    return;
  }

  const result = await deprovision(email, workspace_url, creds);
  res.json(result);
});

app.listen(PORT, () => {
  console.log(`Playwright service running on port ${PORT}`);
});
