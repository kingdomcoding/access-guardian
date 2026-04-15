# AccessGuardian

A demo that mirrors AccessOwl's core workflow — access request, approval, and provisioning — with a Slack bot as the primary UI and a LiveView admin dashboard. Built with Elixir, Phoenix LiveView, Ash Framework, Oban, and DaisyUI.

## Live Demo

**Dashboard:** [accessguardian.josboxoffice.com](https://accessguardian.josboxoffice.com)

**Slack Bot:** [Join the demo workspace](https://join.slack.com/t/access-guardian-demo/shared_invite/zt-3v3fpne7b-d_eXEtT6IBOeGtpWe_QjJw) — type `/request` to try it

Both UIs share the same backend — actions from Slack appear on the dashboard in real-time.

## What to Look At

1. **Visit the dashboard** — see integration status cards (GitHub API, GitLab Playwright), feature pills, and the "Create Test Request" form
2. **Create a test request** — pick an app (note the API/Playwright/Mock labels), pick a user, submit. You're redirected to the request detail.
3. **Approve the request** — click Approve, watch the status change to "Provisioning" then "Granted". If it's a GitHub or GitLab app with real integrations configured, a real invitation is sent.
4. **Try denying** — click Deny on a pending request, enter a reason, confirm. The deny reason is saved and displayed.
5. **Browse applications** at `/applications` — 29 apps grouped by integration type (API, Agentic, SCIM, Manual) with live/mock indicators
6. **Check the integration setup** at `/integrations/setup` — see the GitLab session capture flow and the Cookie-Editor instructions
7. **Try via Slack** — join the workspace, type `/request`, fill the modal. Watch the request appear on the dashboard in real-time.
8. **Configure integrations from the dashboard** — click "Edit" on the GitHub or GitLab integration cards to enter credentials directly from the UI

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
│  • approve_request     │  • GitLab Adapter → HTTP →       │
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

The Playwright service is a separate Docker container running Node.js + Chromium. It exposes three endpoints: `POST /validate-session` (cookie validation during setup), `POST /provision`, and `POST /deprovision`. The Elixir app owns the session state (in Postgres) and the setup UI (a LiveView) — the Playwright service only does what requires a real browser.

## Integration Catalog

AccessGuardian ships with 29 applications across four integration types. Two use real external APIs; the rest use simulated adapters with realistic timing and failure rates.

| Type | Count | Real | Simulated |
|---|---|---|---|
| **API** | 11 | GitHub (REST API) | Google Workspace, Slack, Zoom, 1Password, Datadog, Jira, Linear, Calendly, Amplitude, Loom |
| **Agentic** | 12 | GitLab (Playwright) | Notion, Figma, Canva, HubSpot, Salesforce, Intercom, Asana, Monday.com, ClickUp, Miro, Dropbox |
| **SCIM** | 4 | — | AWS, Okta, JumpCloud, Microsoft 365 |
| **Manual** | 2 | — | Custom Internal Tool, Legacy CRM |

### Real Integrations

**GitHub (API)** — When `GITHUB_TOKEN` and `GITHUB_ORG` are set, requesting access to GitHub actually invites the user to your GitHub organization and adds them to the configured team. Uses GitHub's REST API with proper error handling (idempotent invites, rate limit retries).

**GitLab (Agentic/Playwright)** — Uses persistent browser sessions via Playwright — the same approach AccessOwl uses for their "Agentic Integrations." An admin authenticates once via the setup page at `/integrations/setup`, and the system reuses the stored session for all subsequent provisioning. Playwright navigates to GitLab's group members page, clicks "Invite members", and adds the user by email.

### Setting Up Real Integrations

**GitHub:** Add to `.env`:
```
GITHUB_TOKEN=ghp_your-token
GITHUB_ORG=your-org-name
```

You can also configure these directly from the dashboard — click Edit on the GitHub integration card.

**GitLab (Agentic Integration):** Session-based setup via the web UI:

1. Visit `/integrations/setup` in your browser
2. Navigate to your GitLab group members page in another tab
3. Install the Cookie-Editor browser extension, click Export (JSON format)
4. Paste the exported cookies into the setup form and submit
5. The system validates the cookies via Playwright and saves the session

After setup, all GitLab provisioning uses the stored session automatically. If the session expires, the system detects it, marks it expired in the database, and the admin re-authenticates via the same setup page. The GitLab group path can also be changed from the dashboard — click Edit on the GitLab integration card.

This mirrors how AccessOwl handles apps where API-based provisioning isn't available — by capturing an authenticated session once and automating the admin UI via Playwright.

Without configuration, GitHub and GitLab fall back to simulated adapters — identical behavior to every other app.

## Design Decisions

**Why six adapters (2 real + 4 simulated):**
- **GitHub Adapter** — Real REST API calls to GitHub. Invites users to orgs, adds to teams, handles rate limits.
- **GitLab Agentic Adapter** — Real Playwright browser automation with persistent sessions. Loads a stored session (no login), navigates to the group members page, opens the invite modal, and adds the user by email. Demonstrates the "Agentic Integration" approach AccessOwl uses — session capture via web UI, storageState persistence, session expiry detection.
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

## Running Locally

### Docker Compose (recommended)

```bash
cp .env.example .env  # Fill in credentials
docker compose up --build -d
```

Three services start: PostgreSQL, Playwright (Node + Chromium), and the Elixir app on port 6000. Seeds run automatically on first boot — 29 apps, 6 users, 3 approval policies, and 6 pre-seeded requests in different states.

### Local Development

```bash
mix setup        # Install deps, create DB, migrate, seed
mix phx.server   # Start the server on port 4000
```

Requires Elixir 1.17+, Erlang 27+, and PostgreSQL running locally. The Playwright service needs to be started separately:

```bash
cd playwright-service && npm install && npm start
```

### Slack Bot (self-hosting)

For the demo, the Slack workspace already exists — join via the link in the Live Demo section above.

To set up your own:

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → "Create New App" → "From a manifest"
2. Import `slack_manifest.json` from this repo
3. Install to your workspace, copy the Bot Token and Signing Secret
4. Add to `.env`:
   ```
   SLACK_BOT_TOKEN=xoxb-...
   SLACK_SIGNING_SECRET=...
   SLACK_ENABLED=true
   ```

## AI Development

This project was built with Claude Code as a development partner. Architecture decisions, plan iterations, and product choices were made by the developer; Claude handled implementation — resource definitions, adapter wiring, HEEx templates, and test generation.
