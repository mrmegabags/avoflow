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
      |> ensure_assign(:unread_count, fn -> 0 end)
      |> ensure_assign(:user_label, fn -> @user.name end)
      |> ensure_assign(:current_path, fn -> "/" end)
      |> ensure_assign(:mobile_nav_open, fn -> false end)

    socket =
      Phoenix.LiveView.attach_hook(socket, :set_current_path, :handle_params, fn _params,
                                                                                 uri,
                                                                                 socket ->
        path = URI.parse(uri).path || "/"
        {:cont, assign(socket, :current_path, path)}
      end)

    socket =
      Phoenix.LiveView.attach_hook(socket, :app_shell_events, :handle_event, fn event,
                                                                                params,
                                                                                socket ->
        case {event, params} do
          # TopBar search (supports both payload shapes)
          {"topbar_search", %{"q" => q}} when is_binary(q) ->
            {:halt, assign(socket, :q, q)}

          {"topbar_search", %{"query" => q}} when is_binary(q) ->
            {:halt, assign(socket, :q, q)}

          # Mobile nav
          {"nav_open", _} ->
            {:halt, assign(socket, :mobile_nav_open, true)}

          {"nav_close", _} ->
            {:halt, assign(socket, :mobile_nav_open, false)}

          # Escape closes drawer (phx-window-keydown)
          {"nav_keydown", %{"key" => "Escape"}} ->
            {:halt, assign(socket, :mobile_nav_open, false)}

          {"nav_keydown", %{"key" => "Esc"}} ->
            {:halt, assign(socket, :mobile_nav_open, false)}

          # Keep other topbar events as no-ops by default
          {"topbar_help", _} ->
            {:halt, socket}

          {"topbar_notifications", _} ->
            {:halt, socket}

          {"topbar_user_menu", _} ->
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
