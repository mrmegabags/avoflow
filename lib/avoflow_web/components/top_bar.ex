defmodule AvoflowWeb.Components.TopBar do
  use Phoenix.Component

  @doc "Reusable top bar for LiveView pages."

  attr :query, :string, default: ""
  attr :placeholder, :string, default: "Search batches, suppliers, or logs..."
  attr :unread_notifications, :integer, default: 0
  attr :user_label, :string, default: "User"
  attr :show_user, :boolean, default: true
  attr :show_mobile_tip, :boolean, default: false

  attr :tip_text, :string,
    default: "Tip: Use search to find batches, suppliers, and logs quickly."

  # Optional: hook events (handled by the parent LiveView)
  attr :on_search, :string, default: "topbar_search"
  attr :on_help, :string, default: "topbar_help"
  attr :on_notifications, :string, default: "topbar_notifications"
  attr :on_user_menu, :string, default: "topbar_user_menu"

  def top_bar(assigns) do
    ~H"""
    <header
      role="banner"
      class="fixed inset-x-0 top-0 z-50 border-b border-gray-200 bg-white/90 backdrop-blur supports-[backdrop-filter]:bg-white/70"
    >
      <div class="mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-16 items-center gap-3">
          <form class="min-w-0 flex-1" role="search" aria-label="Site search" phx-submit={@on_search}>
            <div class="relative">
              <label for="topbar-search" class="sr-only">Search</label>

              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <circle cx="11" cy="11" r="8"></circle>
                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
              </svg>

              <input
                id="topbar-search"
                name="q"
                type="search"
                value={@query}
                inputmode="search"
                autocomplete="off"
                placeholder={@placeholder}
                class="h-10 w-full rounded-full bg-gray-50 pl-10 pr-24 text-sm text-gray-900 placeholder:text-gray-400
                       border border-transparent
                       focus:border-[#2E7D32]/30 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20
                       transition"
              />

              <div class="absolute right-3 top-1/2 hidden -translate-y-1/2 sm:flex items-center gap-1">
                <span class="rounded border border-gray-200 bg-white px-1.5 py-0.5 text-[11px] text-gray-500">
                  Ctrl
                </span>
                <span class="text-gray-400 text-xs">+</span>
                <span class="rounded border border-gray-200 bg-white px-1.5 py-0.5 text-[11px] text-gray-500">
                  K
                </span>
              </div>
            </div>
          </form>

          <div class="flex items-center gap-1 sm:gap-2">
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-full p-2 text-gray-500 hover:bg-gray-100 hover:text-gray-700
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
              aria-label="Help"
              phx-click={@on_help}
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
                <circle cx="12" cy="12" r="10"></circle>
                <path d="M9.09 9a3 3 0 1 1 5.82 1c0 2-3 2-3 4"></path>
                <line x1="12" y1="17" x2="12" y2="17"></line>
              </svg>
              <span class="sr-only">Open help</span>
            </button>

            <button
              type="button"
              class="relative inline-flex items-center justify-center rounded-full p-2 text-gray-500 hover:bg-gray-100 hover:text-gray-700
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
              aria-label="Notifications"
              aria-haspopup="menu"
              aria-expanded="false"
              phx-click={@on_notifications}
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
                <path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"></path>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
              </svg>

              <%= if @unread_notifications > 0 do %>
                <span
                  class="absolute right-2 top-2 inline-flex h-2.5 w-2.5 rounded-full bg-red-500 ring-2 ring-white"
                  aria-hidden="true"
                >
                </span>
                <span class="sr-only">You have unread notifications</span>
              <% end %>
            </button>

            <%= if @show_user do %>
              <button
                type="button"
                class="hidden sm:inline-flex items-center gap-2 rounded-full py-1.5 pl-1.5 pr-3 text-sm text-gray-700
                       hover:bg-gray-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
                aria-label="Open user menu"
                aria-haspopup="menu"
                aria-expanded="false"
                phx-click={@on_user_menu}
              >
                <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-gray-200 text-xs font-medium text-gray-700">
                  {avatar_initial(@user_label)}
                </span>
                <span class="max-w-[10rem] truncate">{@user_label}</span>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4 text-gray-500"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  aria-hidden="true"
                >
                  <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
              </button>
            <% end %>
          </div>
        </div>

        <%= if @show_mobile_tip do %>
          <div class="pb-2 sm:hidden">
            <p class="text-xs text-gray-500">{@tip_text}</p>
          </div>
        <% end %>
      </div>
    </header>

    <!-- Spacer to prevent content from hiding under fixed header -->
    <div class={if @show_mobile_tip, do: "pt-20 sm:pt-16", else: "pt-16"}></div>
    """
  end

  defp avatar_initial(nil), do: "U"

  defp avatar_initial(label) when is_binary(label) do
    label
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "U"
      ch -> String.upcase(ch)
    end
  end
end
