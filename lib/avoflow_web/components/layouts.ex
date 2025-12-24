defmodule AvoflowWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AvoflowWeb, :html
  alias AvoflowWeb.Components.Sidebar
  alias AvoflowWeb.Components.TopBar

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  def app(assigns) do
    assigns =
      assigns
      |> assign(:navigation, Map.get(assigns, :navigation, []))
      |> assign(:user, Map.get(assigns, :user, %{initials: "", name: "", role: ""}))
      |> assign(:q, Map.get(assigns, :q, ""))
      |> assign(:unread_count, Map.get(assigns, :unread_count, 0))
      |> assign(:user_label, Map.get(assigns, :user_label, ""))
      |> assign(:current_path, Map.get(assigns, :current_path, "/"))
      |> assign(:mobile_nav_open, Map.get(assigns, :mobile_nav_open, false))

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <Sidebar.sidebar navigation={@navigation} current_path={@current_path} user={@user} />
      
    <!-- Mobile drawer -->
      <%= if @mobile_nav_open do %>
        <div
          class="fixed inset-0 z-40 lg:hidden"
          phx-window-keydown="nav_keydown"
        >
          <!-- Overlay (click to close) -->
          <button
            type="button"
            phx-click="nav_close"
            aria-label="Close navigation menu"
            class="absolute inset-0 bg-black/30 focus:outline-none"
          >
          </button>
          
    <!-- Drawer -->
          <div class="absolute left-0 top-0 h-full w-72 bg-[#1A1C1E] text-white shadow-xl">
            <div class="h-16 flex items-center justify-between px-4 border-b border-gray-800">
              <div class="flex items-center space-x-2">
                <div class="w-8 h-8 bg-[#2E7D32] rounded-lg flex items-center justify-center">
                  <span class="font-bold text-white">A</span>
                </div>
                <span class="font-bold text-lg tracking-tight">AvoFlow</span>
              </div>

              <button
                type="button"
                phx-click="nav_close"
                aria-label="Close navigation menu"
                class="rounded-full p-2 text-gray-300 hover:bg-white/10 hover:text-white
                       focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  aria-hidden="true"
                >
                  <line x1="18" y1="6" x2="6" y2="18"></line>
                  <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
              </button>
            </div>

            <nav class="py-6 px-3 space-y-1 overflow-y-auto h-[calc(100%-4rem)]">
              <%= for item <- @navigation do %>
                <.link
                  navigate={nav_path(item.href)}
                  phx-click="nav_close"
                  class={
                    [
                      "flex items-center px-3 py-2.5 rounded-md text-sm font-medium transition-all duration-200",
                      "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus-visible:ring-offset-2 focus-visible:ring-offset-[#1A1C1E]",
                      if(String.starts_with?((@current_path || "/") <> "/", item.href <> "/"),
                        do: "bg-[#2E7D32] text-white shadow-md translate-x-1",
                        else: "text-gray-400 hover:text-white hover:bg-white/5"
                      )
                    ]
                    |> Enum.join(" ")
                  }
                >
                  <span class="w-5 h-5 mr-3 flex-shrink-0"></span>
                  {item.name}
                </.link>
              <% end %>
            </nav>
          </div>
        </div>
      <% end %>

      <div class="lg:pl-60">
        <TopBar.top_bar
          class="lg:left-60"
          query={@q}
          unread_notifications={@unread_count}
          user_label={@user_label}
          on_search="topbar_search"
          on_help="topbar_help"
          on_notifications="topbar_notifications"
          on_user_menu="topbar_user_menu"
        >
          <:left>
            <!-- Mobile menu button -->
            <button
              type="button"
              phx-click="nav_open"
              aria-label="Open navigation menu"
              class="lg:hidden inline-flex items-center justify-center rounded-full p-2 text-gray-600 hover:bg-gray-100 hover:text-gray-900
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <line x1="4" y1="6" x2="20" y2="6"></line>
                <line x1="4" y1="12" x2="20" y2="12"></line>
                <line x1="4" y1="18" x2="20" y2="18"></line>
              </svg>
            </button>
          </:left>
        </TopBar.top_bar>
        
    <!-- Fixed top bar spacer (contract rule) -->
        <div class="pt-16">
          <main>
            <div class="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8 py-8 sm:py-10">
              {@inner_content}
            </div>
          </main>
        </div>
      </div>
    </div>
    """
  end

  # Keep these helper functions somewhere in the same module (Layouts).
  # If you already have them, do not duplicate.
  defp nav_path("/"), do: ~p"/"
  defp nav_path("/suppliers"), do: ~p"/suppliers"
  defp nav_path("/batches"), do: ~p"/batches"
  defp nav_path("/inventory"), do: ~p"/inventory"
  defp nav_path("/production"), do: ~p"/production"
  defp nav_path(other) when is_binary(other), do: other

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
