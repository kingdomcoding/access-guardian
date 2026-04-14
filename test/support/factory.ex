defmodule AccessGuardian.Factory do
  def create_org!(attrs \\ %{}) do
    {:ok, org} =
      AccessGuardian.Catalog.create_organization(
        Map.merge(%{name: "TestCorp", slug: "test-#{Ash.UUID.generate()}"}, attrs)
      )

    org
  end

  def create_user!(org, attrs \\ %{}) do
    {:ok, user} =
      AccessGuardian.Catalog.create_user(
        Map.merge(
          %{
            organization_id: org.id,
            email: "user-#{Ash.UUID.generate()}@test.com",
            full_name: "Test User"
          },
          attrs
        )
      )

    user
  end

  def create_app!(org, attrs \\ %{}) do
    {:ok, app} =
      AccessGuardian.Catalog.create_application(
        Map.merge(%{organization_id: org.id, name: "TestApp", integration_type: :api}, attrs)
      )

    app
  end

  def create_policy!(org, steps \\ []) do
    {:ok, policy} =
      AccessGuardian.Catalog.create_policy(%{
        organization_id: org.id,
        name: "Policy-#{Ash.UUID.generate()}",
        is_default: true
      })

    Enum.each(steps, fn step_attrs ->
      AccessGuardian.Catalog.create_step(Map.put(step_attrs, :approval_policy_id, policy.id))
    end)

    policy
  end
end
