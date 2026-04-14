defmodule AccessGuardian.Provisioning.Adapters.AgenticAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter
  require Logger

  @steps [:login, :navigate, :fill_form, :submit, :verify]

  @impl true
  def provision(app, _user, _entitlements) do
    Enum.reduce_while(@steps, :ok, fn step, _acc ->
      Process.sleep(Enum.random(200..1000))
      Logger.info("[AgenticAdapter] #{app.name}: step=#{step}")

      case :rand.uniform(100) do
        n when n <= 5 ->
          {:halt, {:error, :permanent, "UI changed — selector not found at #{step}"}}

        n when n <= 25 ->
          {:halt, {:error, :transient, "Page timeout at #{step}"}}

        _ ->
          {:cont, :ok}
      end
    end)
    |> case do
      :ok -> {:ok, %{external_account_id: "agentic-#{Ash.UUID.generate()}"}}
      error -> error
    end
  end

  @impl true
  def deprovision(_app, _user), do: :ok
end
