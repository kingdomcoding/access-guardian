defmodule AccessGuardian.Repo do
  use Ecto.Repo,
    otp_app: :access_guardian,
    adapter: Ecto.Adapters.Postgres
end
