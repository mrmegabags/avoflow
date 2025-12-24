defmodule Avoflow.Repo do
  use Ecto.Repo,
    otp_app: :avoflow,
    adapter: Ecto.Adapters.Postgres
end
