ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AccessGuardian.Repo, :manual)

Mox.defmock(AccessGuardian.Slack.ApiMock, for: AccessGuardian.Slack.ApiBehaviour)
