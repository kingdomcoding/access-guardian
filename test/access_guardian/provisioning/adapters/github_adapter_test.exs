defmodule AccessGuardian.Provisioning.Adapters.GithubAdapterTest do
  use ExUnit.Case, async: true

  alias AccessGuardian.Provisioning.Adapters.GithubAdapter

  test "implements the Adapter behaviour" do
    Code.ensure_loaded!(GithubAdapter)
    assert function_exported?(GithubAdapter, :provision, 3)
    assert function_exported?(GithubAdapter, :deprovision, 2)
  end
end
