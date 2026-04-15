# AccessGuardian

A demo that mirrors AccessOwl's core workflow — access request, approval, and provisioning — with a Slack bot as the primary UI and a LiveView admin dashboard. Built with Elixir, Phoenix LiveView, Ash Framework, Oban, and Tailwind CSS.

## Quick Start (Web Only)

```bash
docker compose up -d        # Start PostgreSQL
mix setup                   # Install deps, create DB, migrate, seed
mix phx.server              # Start the server
```

Visit [localhost:4000](http://localhost:4000). The seed data creates 6 users, 7 applications, 3 approval policies, and several requests in different states.

## Quick Start (With Slack)

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → "Create New App" → "From a manifest"
2. Import `slack_manifest.json` from this repo
3. Install to your workspace, copy the Bot Token and Signing Secret
4. Create a `.env` file:
   ```
   export SLACK_BOT_TOKEN=xoxb-...
   export SLACK_SIGNING_SECRET=...
   export SLACK_ENABLED=true
   ```
5. `source .env && ngrok http 4000` — update Slack app URLs with your ngrok domain
6. `mix ecto.reset` to re-seed with Slack user mapping
7. Type `/request` in Slack

## What to Look At

1. **Open the request queue** at `/requests` — notice requests in different states (pending, granted, denied, rejected)
2. **Click a pending request** — see the approval timeline — click **Approve** — watch the status update in real-time as provisioning runs
3. **Check the dashboard** at `/` — KPI cards update when requests change state
4. **If Slack is configured**: type `/request` → fill the modal → submit → see it appear on the dashboard instantly. Approve from Slack → dashboard updates. Approve from dashboard → Slack message updates.

## Architecture

```
┌───────────────────────────┐  ┌───────────────────────────┐
│  SLACK BOT (Primary UX)   │  │  LIVEVIEW DASHBOARD       │
│  /request → modal         │  │  Request queue + detail    │
│  Approval DMs + buttons   │  │  Approve/deny actions      │
│  Provisioning result DMs  │  │  Real-time PubSub updates  │
└─────────────┬─────────────┘  └──────────────┬────────────┘
              │                                │
              └──────────┬─────────────────────┘
                         │
              Both call the same Ash domain APIs
                         │
┌────────────────────────┼─────────────────────────────────┐
│  Access Domain (Ash)   │  Provisioning Context            │
│  • create_request      │  • GitHub Adapter (real API)     │
│  • approve_request     │  • Notion Adapter → HTTP →       │
│  • deny_request        │      Playwright Service          │
│  • complete_provisioning│  • Simulated adapters (mock)    │
│  • fail_provisioning   │  • Oban ProvisionWorker          │
└────────────────────────┼─────────────────────────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
    ▼                    ▼                    ▼
PostgreSQL     Playwright Service     GitHub API
               (Node + Chromium)     (api.github.com)
               port 3000
```

The Playwright service is a separate Docker container running Node.js + Chromium. The Elixir app calls it via HTTP — mirroring AccessOwl's architecture where the Elixir core and TypeScript integration layer are separate services.

## Integration Catalog

AccessGuardian ships with 28 applications across four integration types. Two use real external APIs; the rest use simulated adapters with realistic timing and failure rates.

| Type | Count | Real | Simulated |
|---|---|---|---|
| **API** | 12 | GitHub (REST API) | Google Workspace, Slack, Zoom, 1Password, Datadog, Jira, Linear, Calendly, Amplitude, Loom |
| **Agentic** | 12 | Notion (Playwright) | Figma, Canva, HubSpot, Salesforce, Intercom, Asana, Monday.com, ClickUp, Miro, Dropbox |
| **SCIM** | 4 | — | AWS, Okta, JumpCloud, Microsoft 365 |
| **Manual** | 2 | — | Custom Internal Tool, Legacy CRM |

### Real Integrations

**GitHub (API)** — When `GITHUB_TOKEN` and `GITHUB_ORG` are set, requesting access to GitHub actually invites the user to your GitHub organization and adds them to the configured team. Uses GitHub's REST API with proper error handling (idempotent invites, rate limit retries).

**Notion (Agentic/Playwright)** — When `NOTION_EMAIL` and `NOTION_PASSWORD` are set, requesting access to Notion runs a real Playwright browser automation that logs into Notion's admin UI, navigates to Settings → Members, and invites the user by email. This is the exact approach AccessOwl uses for their "Agentic Integrations."

### Setting Up Real Integrations

Add to `.env`:
```
GITHUB_TOKEN=ghp_your-token
GITHUB_ORG=your-org-name
NOTION_EMAIL=admin@company.com
NOTION_PASSWORD=your-password
NOTION_WORKSPACE_URL=https://www.notion.so/yourworkspace
```

Without these variables, GitHub and Notion fall back to simulated adapters — identical behavior to every other app.

## Design Decisions

**Why six adapters (2 real + 4 simulated):**
- **GitHub Adapter** — Real REST API calls to GitHub. Invites users to orgs, adds to teams, handles rate limits.
- **Notion Adapter** — Real Playwright browser automation. Logs in, navigates admin UI, invites by email. Demonstrates the exact "Agentic Integration" approach AccessOwl uses.
- **API Adapter** (simulated) — 200ms-2s latency, 10% transient failures. Used by 10 mock API apps.
- **Agentic Adapter** (simulated) — 1-5s multi-step latency, 20% transient, 5% "UI changed" failures. Used by 10 mock agentic apps.
- **SCIM Adapter** (simulated) — Okta group assignment, low failure rate.
- **Manual Adapter** — No automation, sends DM to app admin with Grant/Reject buttons.

**Why the Agentic adapter has a 20% failure rate:** This models the real fragility of browser automation at scale. Playwright scripts break when SaaS vendors redesign their admin UI. The system must be resilient — Oban retries transient failures with backoff, while permanent failures are reported immediately.

**How Slack and LiveView share zero business logic:** Both call the same Ash domain functions (`Access.approve_request`, `Access.deny_request`, etc.). The Slack controller maps Slack payloads to domain calls. The LiveView maps `handle_event` to domain calls. PubSub notifies both surfaces independently.

**Why Oban for provisioning:** Provisioning involves network calls to external services (real or simulated). Inline execution would block the request. Oban provides retry with exponential backoff, transient vs. permanent error distinction, and queue isolation.

**Why Ash Framework:** Declarative PubSub (every action auto-broadcasts), composable Changes (approval chain resolution, step advancement, provisioning enqueue), reusable Validations (status checks), and code interfaces that eliminate boilerplate.

**Why multi-step approval chains:** AccessOwl supports configurable approval policies with ordered steps and different response modes (first-to-respond, everyone-must-approve). This demo implements the full model.

## What I'd Build Next

**Onboarding with template auto-assignment:** Templates bundle applications + permissions for a job role ("Backend Engineer" → GitHub + Notion + AWS). Auto-assignment rules match HRIS attributes (department, job title) to templates with AND logic and priority-based conflict resolution. A simulator lets admins dry-run template matching.

**Offboarding with cascading revocation:** When an employee leaves, the system creates revocations for all their active app accounts and executes them through the same adapter pipeline.

**Access review campaigns:** Periodic compliance audits where managers verify their reports' access. Supports SOC 2, ISO 27001. Each decision is an auditable record, exportable as CSV.

**Webhook event system with Ed25519 signing:** Matching AccessOwl's documented RFC 9421 implementation. Commands for dispatch/delivery, event-driven retry with exponential backoff (19 retries, 24h window).

**Mandatory resource dependency graph:** Apps with mandatory root resources create dependency chains where approving access to a sub-resource requires the parent first. Denial cascades through the dependency tree.

## Running Tests

```bash
mix test
```

## AI Development

This project was built with Claude Code as a development partner — used for architecture planning, Ash resource design, and test generation.
