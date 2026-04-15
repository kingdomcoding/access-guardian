alias AccessGuardian.{Catalog, Access}
require Ash.Query

IO.puts("Seeding AccessGuardian...")

# --- Organization ---
{:ok, org} = Catalog.create_organization(%{name: "TechCorp", slug: "techcorp"})

# --- Users ---
{:ok, sarah} =
  Catalog.create_user(%{
    organization_id: org.id,
    email: "sarah@techcorp.com",
    full_name: "Sarah Chen",
    department: "Engineering",
    job_title: "VP Engineering",
    org_role: :org_admin
  })

{:ok, marcus} =
  Catalog.create_user(%{
    organization_id: org.id,
    email: "marcus@techcorp.com",
    full_name: "Marcus Johnson",
    department: "IT",
    job_title: "IT Manager",
    org_role: :org_admin
  })

{:ok, priya} =
  Catalog.create_user(%{
    organization_id: org.id,
    email: "priya@techcorp.com",
    full_name: "Priya Patel",
    department: "Engineering",
    job_title: "Senior Engineer",
    manager_id: sarah.id
  })

{:ok, david} =
  Catalog.create_user(%{
    organization_id: org.id,
    email: "david@techcorp.com",
    full_name: "David Kim",
    department: "Sales",
    job_title: "Account Executive",
    manager_id: marcus.id
  })

{:ok, elena} =
  Catalog.create_user(%{
    organization_id: org.id,
    email: "elena@techcorp.com",
    full_name: "Elena Rodriguez",
    department: "Sales",
    job_title: "Sales Director",
    org_role: :org_admin
  })

{:ok, james} =
  Catalog.create_user(%{
    organization_id: org.id,
    email: "james@techcorp.com",
    full_name: "James Wilson",
    department: "Engineering",
    job_title: "Junior Engineer",
    manager_id: sarah.id
  })

# --- Approval Policies ---
{:ok, default_policy} =
  Catalog.create_policy(%{organization_id: org.id, name: "Default", is_default: true})

Catalog.create_step(%{
  approval_policy_id: default_policy.id,
  step_index: 0,
  approver_type: :manager,
  response_mode: :first_to_respond
})

{:ok, eng_sensitive} =
  Catalog.create_policy(%{organization_id: org.id, name: "Engineering Sensitive"})

Catalog.create_step(%{
  approval_policy_id: eng_sensitive.id,
  step_index: 0,
  approver_type: :manager,
  response_mode: :first_to_respond
})

Catalog.create_step(%{
  approval_policy_id: eng_sensitive.id,
  step_index: 1,
  approver_type: :individual,
  specific_user_id: sarah.id,
  response_mode: :first_to_respond
})

{:ok, auto_policy} =
  Catalog.create_policy(%{organization_id: org.id, name: "Auto-Approve"})

# =============================================================================
# APPLICATION CATALOG (30+ apps: 2 real, 28 mock)
# =============================================================================

# --- REAL INTEGRATIONS ---

{:ok, github} =
  Catalog.create_application(%{
    organization_id: org.id,
    name: "GitHub",
    integration_type: :api,
    business_owner_id: sarah.id,
    approval_policy_id: eng_sensitive.id,
    config: %{
      "github_org" => System.get_env("GITHUB_ORG", ""),
      "github_team" => "engineering"
    }
  })

{:ok, notion} =
  Catalog.create_application(%{
    organization_id: org.id,
    name: "Notion",
    integration_type: :agentic,
    business_owner_id: sarah.id,
    approval_policy_id: default_policy.id,
    config: %{
      "notion_workspace_url" => System.get_env("NOTION_WORKSPACE_URL", "")
    }
  })

# --- MOCK API INTEGRATIONS ---

mock_api_apps = [
  {"Google Workspace", marcus.id, auto_policy.id},
  {"Slack", marcus.id, auto_policy.id},
  {"Zoom", marcus.id, auto_policy.id},
  {"1Password", marcus.id, default_policy.id},
  {"Datadog", sarah.id, eng_sensitive.id},
  {"Jira", sarah.id, default_policy.id},
  {"Linear", sarah.id, default_policy.id},
  {"Calendly", elena.id, auto_policy.id},
  {"Amplitude", sarah.id, default_policy.id},
  {"Loom", elena.id, auto_policy.id}
]

Enum.each(mock_api_apps, fn {name, owner_id, policy_id} ->
  Catalog.create_application(%{
    organization_id: org.id,
    name: name,
    integration_type: :api,
    business_owner_id: owner_id,
    approval_policy_id: policy_id
  })
end)

# --- MOCK AGENTIC INTEGRATIONS ---

mock_agentic_apps = [
  {"Figma", elena.id, default_policy.id},
  {"Canva", elena.id, auto_policy.id},
  {"HubSpot", elena.id, default_policy.id},
  {"Salesforce", elena.id, eng_sensitive.id},
  {"Intercom", marcus.id, default_policy.id},
  {"Asana", sarah.id, default_policy.id},
  {"Monday.com", elena.id, default_policy.id},
  {"ClickUp", sarah.id, default_policy.id},
  {"Miro", sarah.id, auto_policy.id},
  {"Dropbox", marcus.id, default_policy.id}
]

Enum.each(mock_agentic_apps, fn {name, owner_id, policy_id} ->
  Catalog.create_application(%{
    organization_id: org.id,
    name: name,
    integration_type: :agentic,
    business_owner_id: owner_id,
    approval_policy_id: policy_id
  })
end)

# --- MOCK SCIM INTEGRATIONS ---

mock_scim_apps = [
  {"AWS", sarah.id, eng_sensitive.id},
  {"Okta", marcus.id, eng_sensitive.id},
  {"JumpCloud", marcus.id, default_policy.id},
  {"Microsoft 365", marcus.id, default_policy.id}
]

Enum.each(mock_scim_apps, fn {name, owner_id, policy_id} ->
  Catalog.create_application(%{
    organization_id: org.id,
    name: name,
    integration_type: :scim,
    business_owner_id: owner_id,
    approval_policy_id: policy_id
  })
end)

# --- MOCK MANUAL INTEGRATIONS ---

mock_manual_apps = [
  {"Custom Internal Tool", marcus.id, default_policy.id},
  {"Legacy CRM", elena.id, default_policy.id}
]

Enum.each(mock_manual_apps, fn {name, owner_id, policy_id} ->
  Catalog.create_application(%{
    organization_id: org.id,
    name: name,
    integration_type: :manual,
    business_owner_id: owner_id,
    approval_policy_id: policy_id
  })
end)

# --- Admin Assignments ---
Catalog.create_admin_assignment(%{application_id: github.id, user_id: priya.id})

# =============================================================================
# PRE-SEEDED ACCESS REQUESTS (6 states)
# =============================================================================

# 1. Pending approval — David wants GitHub (2-step Engineering Sensitive)
Access.create_request(%{
  organization_id: org.id,
  affected_user_id: david.id,
  requested_by_id: david.id,
  application_id: github.id,
  request_reason: "Need repo access for client integration"
})

# 2. Pending approval — James wants AWS
{:ok, [aws | _]} =
  Ash.read(
    Catalog.Application
    |> Ash.Query.filter(name == "AWS" and organization_id == ^org.id)
  )

Access.create_request(%{
  organization_id: org.id,
  affected_user_id: james.id,
  requested_by_id: james.id,
  application_id: aws.id,
  request_reason: "Need staging access for deployment testing"
})

# 3. Denied — David's Figma request
{:ok, [figma | _]} =
  Ash.read(
    Catalog.Application
    |> Ash.Query.filter(name == "Figma" and organization_id == ^org.id)
  )

{:ok, figma_req} =
  Access.create_request(%{
    organization_id: org.id,
    affected_user_id: david.id,
    requested_by_id: david.id,
    application_id: figma.id,
    request_reason: "Want to create marketing mockups"
  })

if figma_req.status == :pending_approval do
  Access.deny_request(figma_req, %{denier_id: marcus.id, reason: "Use Canva instead"})
end

# 4. Granted — Priya got Notion
Access.AccessRequest
|> Ash.Changeset.for_create(:create, %{
  organization_id: org.id,
  affected_user_id: priya.id,
  requested_by_id: priya.id,
  application_id: notion.id,
  request_reason: "Engineering wiki access"
})
|> Ash.Changeset.force_change_attribute(:status, :granted)
|> Ash.Changeset.force_change_attribute(:granted_at, DateTime.utc_now())
|> Ash.Changeset.force_change_attribute(:provisioner_type, "automation")
|> Ash.Changeset.force_change_attribute(:adapter_type, "agentic")
|> Ash.Changeset.force_change_attribute(:external_account_id, "agentic-demo-001")
|> Ash.create!()

# 5. Pending manual — David wants Custom Internal Tool
{:ok, [internal_tool | _]} =
  Ash.read(
    Catalog.Application
    |> Ash.Query.filter(name == "Custom Internal Tool" and organization_id == ^org.id)
  )

Access.AccessRequest
|> Ash.Changeset.for_create(:create, %{
  organization_id: org.id,
  affected_user_id: david.id,
  requested_by_id: david.id,
  application_id: internal_tool.id,
  request_reason: "Need access to internal dashboard"
})
|> Ash.Changeset.force_change_attribute(:status, :provisioning)
|> Ash.Changeset.force_change_attribute(:pending_manual, true)
|> Ash.Changeset.force_change_attribute(:provisioner_type, "manual")
|> Ash.Changeset.force_change_attribute(:approved_at, DateTime.utc_now())
|> Ash.create!()

# 6. Rejected — James Notion request (agentic adapter failure)
Access.AccessRequest
|> Ash.Changeset.for_create(:create, %{
  organization_id: org.id,
  affected_user_id: james.id,
  requested_by_id: james.id,
  application_id: notion.id,
  request_reason: "Documentation access"
})
|> Ash.Changeset.force_change_attribute(:status, :rejected)
|> Ash.Changeset.force_change_attribute(:rejected_at, DateTime.utc_now())
|> Ash.Changeset.force_change_attribute(:adapter_type, "agentic")
|> Ash.Changeset.force_change_attribute(
  :reject_reason,
  "UI changed — selector not found at fill_form"
)
|> Ash.create!()

IO.puts("✅ Seed complete: 28 apps, 6 requests. Visit http://localhost:4000")
