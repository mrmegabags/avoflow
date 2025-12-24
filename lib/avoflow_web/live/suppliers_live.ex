defmodule AvoflowWeb.SuppliersLive do
  use AvoflowWeb, :live_view

  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    suppliers = [
      %{
        id: "1",
        name: "Avocorp",
        contact_name: "John Doe",
        phone: "+254 712 345 678",
        weekly_volume: 80,
        avg_ripening_days: 3,
        status: "Active",
        default_variety: "Hass",
        ratings: %{delivery: 4.5, quality: 4.0, ripeness: 4.2, reliability: 4.7}
      },
      %{
        id: "2",
        name: "GreenFarm",
        contact_name: "Jane Smith",
        phone: "+254 722 987 654",
        weekly_volume: 50,
        avg_ripening_days: 5,
        status: "Active",
        default_variety: "Fuerte",
        ratings: %{delivery: 4.0, quality: 4.5, ripeness: 4.0, reliability: 4.2}
      },
      %{
        id: "3",
        name: "AvoMasters",
        contact_name: "Mike Johnson",
        phone: "+254 733 111 222",
        weekly_volume: 20,
        avg_ripening_days: 2,
        status: "Inactive",
        default_variety: "Hass",
        ratings: %{delivery: 3.0, quality: 3.5, ripeness: 3.0, reliability: 3.0}
      }
    ]

    {:ok,
     assign(socket,
       page_title: "Suppliers",
       q: "",
       unread_count: 1,
       suppliers: suppliers
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="">
      <div class="">
        <!-- Header -->
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-6">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Suppliers</h1>
            <p class="text-gray-500 mt-1">Manage avocado suppliers and performance</p>
          </div>

          <button
            type="button"
            phx-click="new_supplier"
            class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-full text-sm font-medium
                   bg-[#2E7D32] text-white hover:brightness-95
                   focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
          >
            <!-- Plus icon -->
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            New Supplier
          </button>
        </div>
        
    <!-- Table -->
        <section class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
          <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Name</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Contact</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Weekly Volume</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Avg Ripening</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Status</th>
                  <th class="px-5 py-3 text-right font-semibold text-gray-700">Actions</th>
                </tr>
              </thead>

              <tbody class="divide-y divide-gray-100">
                <%= for s <- @suppliers do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-5 py-4 font-medium text-gray-900 whitespace-nowrap">{s.name}</td>

                    <td class="px-5 py-4 text-gray-700">
                      <div class="flex flex-col">
                        <span class="text-gray-900">{s.contact_name}</span>
                        <span class="text-xs text-gray-500">{s.phone}</span>
                      </div>
                    </td>

                    <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{s.weekly_volume} kg</td>
                    <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                      {s.avg_ripening_days} days
                    </td>

                    <td class="px-5 py-4 whitespace-nowrap">
                      <.status_badge status={s.status} />
                    </td>

                    <td class="px-5 py-4 text-right whitespace-nowrap">
                      <button
                        type="button"
                        phx-click="view_supplier"
                        phx-value-id={s.id}
                        class="text-sm font-medium text-gray-600 hover:text-gray-900
                               rounded-lg px-2 py-1 hover:bg-gray-100
                               focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
                      >
                        View
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  # Events (no-op placeholders)
  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket), do: {:noreply, assign(socket, :q, q)}
  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  def handle_event("new_supplier", _params, socket), do: {:noreply, socket}
  def handle_event("view_supplier", _params, socket), do: {:noreply, socket}

  # Simple function component (this is the critical fix)
  attr :status, :string, required: true

  def status_badge(assigns) do
    {cls, label} =
      case assigns.status do
        "Active" -> {"bg-green-50 text-green-700 ring-green-600/20", "Active"}
        _ -> {"bg-gray-50 text-gray-700 ring-gray-600/20", assigns.status || "Inactive"}
      end

    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      {@label}
    </span>
    """
  end
end
