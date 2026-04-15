defmodule AccessGuardian.Provisioning.AdapterSelectionTest do
  use ExUnit.Case, async: true

  alias AccessGuardian.Provisioning.Adapters
  alias AccessGuardian.Provisioning.ProvisionWorker

  setup do
    System.delete_env("GITHUB_TOKEN")
    System.delete_env("NOTION_EMAIL")

    on_exit(fn ->
      System.delete_env("GITHUB_TOKEN")
      System.delete_env("NOTION_EMAIL")
    end)

    :ok
  end

  test "api app with empty config uses simulated adapter" do
    app = %{integration_type: :api, config: %{}}
    assert ProvisionWorker.select_adapter(app) == Adapters.ApiAdapter
  end

  test "api app with github config but no token uses simulated adapter" do
    app = %{integration_type: :api, config: %{"github_org" => "my-org"}}
    assert ProvisionWorker.select_adapter(app) == Adapters.ApiAdapter
  end

  test "api app with github config and token uses real adapter" do
    System.put_env("GITHUB_TOKEN", "test-token")
    app = %{integration_type: :api, config: %{"github_org" => "my-org"}}
    assert ProvisionWorker.select_adapter(app) == Adapters.GithubAdapter
  end

  test "agentic app with empty config uses simulated adapter" do
    app = %{integration_type: :agentic, config: %{}}
    assert ProvisionWorker.select_adapter(app) == Adapters.AgenticAdapter
  end

  test "agentic app with notion config and env uses real adapter" do
    System.put_env("NOTION_EMAIL", "test@test.com")
    app = %{integration_type: :agentic, config: %{"notion_workspace_url" => "https://notion.so/ws"}}
    assert ProvisionWorker.select_adapter(app) == Adapters.NotionAdapter
  end

  test "scim always uses simulated" do
    app = %{integration_type: :scim, config: %{}}
    assert ProvisionWorker.select_adapter(app) == Adapters.ScimAdapter
  end

  test "manual always uses manual" do
    app = %{integration_type: :manual, config: %{}}
    assert ProvisionWorker.select_adapter(app) == Adapters.ManualAdapter
  end
end
