defmodule Avoflow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AvoflowWeb.Telemetry,
      Avoflow.Repo,
      {DNSCluster, query: Application.get_env(:avoflow, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Avoflow.PubSub},
      # Start a worker by calling: Avoflow.Worker.start_link(arg)
      # {Avoflow.Worker, arg},
      # Start to serve requests, typically the last entry
      AvoflowWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Avoflow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AvoflowWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
