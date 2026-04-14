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
│  • create_request      │  • Adapter behaviour             │
│  • approve_request     │  • API / Agentic / SCIM / Manual │
│  • deny_request        │  • Oban ProvisionWorker          │
│  • complete_provisioning                                  │
│  • fail_provisioning                                      │
└───────────────────────────────────────────────────────────┘
                         │
                    PostgreSQL
```

## Design Decisions

**Why four adapters and what each simulates:**
- **API Adapter** (Google Workspace, Slack) — simulated REST calls, 200ms-2s latency, 10% transient failures
- **Agentic Adapter** (Notion, Figma) — simulated Playwright browser automation, 1-5s multi-step latency, 20% transient failures, 5% permanent "UI changed" failures. Models the real fragility of browser automation at scale — AccessOwl's daily engineering challenge.
- **SCIM Adapter** (AWS via Okta) — simulated Okta group assignment, low failure rate
- **Manual Adapter** (HubSpot) — no automation, sends DM to app admin with Grant/Reject buttons

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
