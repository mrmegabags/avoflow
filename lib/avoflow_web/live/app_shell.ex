defmodule AvoflowWeb.Live.AppShell do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  @navigation [
    %{name: "Dashboard", href: "/dashboard"},
    %{name: "Suppliers", href: "/suppliers"},
    %{name: "Batches", href: "/batches"},
    %{name: "Inventory", href: "/inventory"},
    %{name: "Production", href: "/production"}
  ]

  @user %{initials: "JD", name: "John Doe", role: "Plant Manager"}

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> ensure_assign(:navigation, fn -> @navigation end)
      |> ensure_assign(:user, fn -> @user end)
      |> ensure_assign(:q, fn -> "" end)
      |> ensure_assign(:unread_count, fn -> 3 end)
      |> ensure_assign(:user_label, fn -> @user.name end)
      |> ensure_assign(:current_path, fn -> "/" end)

    socket =
      Phoenix.LiveView.attach_hook(socket, :set_current_path, :handle_params, fn _params,
                                                                                 uri,
                                                                                 socket ->
        path = URI.parse(uri).path || "/"
        {:cont, assign(socket, :current_path, path)}
      end)

    socket =
      Phoenix.LiveView.attach_hook(socket, :topbar_events, :handle_event, fn event,
                                                                             params,
                                                                             socket ->
        case {event, params} do
          {"topbar_search", %{"query" => q}} when is_binary(q) ->
            {:halt, assign(socket, :q, q)}

          {"topbar_clear_search", _} ->
            {:halt, assign(socket, :q, "")}

          {"topbar_open_notifications", _} ->
            {:halt, socket}

          {"topbar_open_profile", _} ->
            {:halt, socket}

          _ ->
            {:cont, socket}
        end
      end)

    {:cont, socket}
  end

  defp ensure_assign(socket, key, fun) when is_function(fun, 0) do
    if Map.has_key?(socket.assigns, key), do: socket, else: assign(socket, key, fun.())
  end
end
