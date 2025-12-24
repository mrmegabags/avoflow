defmodule AvoflowWeb.BatchesLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar
  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    batches = [
      %{
        id: "B-009",
        supplier_id: "1",
        supplier_name: "Avocorp",
        variety: "Hass",
        date_received: "2023-10-24",
        quantity_kg: 450,
        ripeness_score: 6,
        defects_percentage: 2.5,
        status: "Ready"
      },
      %{
        id: "B-010",
        supplier_id: "2",
        supplier_name: "GreenFarm",
        variety: "Fuerte",
        date_received: "2023-10-25",
        quantity_kg: 320,
        ripeness_score: 3,
        defects_percentage: 1.2,
        status: "Ripening"
      },
      %{
        id: "B-011",
        supplier_id: "1",
        supplier_name: "Avocorp",
        variety: "Hass",
        date_received: "2023-10-26",
        quantity_kg: 500,
        ripeness_score: 1,
        defects_percentage: 0.5,
        status: "Unripe"
      }
    ]

    {:ok,
     assign(socket,
       page_title: "Batches",
       q: "",
       unread_count: 0,
       batches: batches
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
            <h1 class="text-2xl font-bold text-gray-900">Batches</h1>
            <p class="text-gray-500 mt-1">Track incoming deliveries and ripening status</p>
          </div>

          <div class="flex flex-row gap-3 sm:justify-end">
            <button
              type="button"
              phx-click="filter"
              class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-full text-sm font-medium
                     bg-gray-100 text-gray-900 hover:bg-gray-200
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
            >
              <!-- Filter icon -->
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
                <path d="M22 3H2l8 9v7l4 2v-9l8-9Z"></path>
              </svg>
              Filter
            </button>

            <.link
              navigate={~p"/batches/new"}
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
              New Batch Intake
            </.link>
          </div>
        </div>
        
    <!-- Table -->
        <section class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
          <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Batch ID</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Supplier</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Variety</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Received</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Quantity</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Ripeness</th>
                  <th class="px-5 py-3 text-left font-semibold text-gray-700">Status</th>
                  <th class="px-5 py-3 text-right font-semibold text-gray-700">Actions</th>
                </tr>
              </thead>

              <tbody class="divide-y divide-gray-100">
                <%= for b <- @batches do %>
                  <tr
                    class="hover:bg-gray-50 cursor-pointer"
                    phx-click="row_click"
                    phx-value-id={b.id}
                  >
                    <td class="px-5 py-4 font-medium text-gray-900 whitespace-nowrap">{b.id}</td>
                    <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{b.supplier_name}</td>
                    <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{b.variety}</td>
                    <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{b.date_received}</td>
                    <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{b.quantity_kg} kg</td>

                    <td class="px-5 py-4 whitespace-nowrap">
                      <.ripeness_badge score={b.ripeness_score} />
                    </td>

                    <td class="px-5 py-4 whitespace-nowrap">
                      <.status_badge status={b.status} />
                    </td>

                    <td class="px-5 py-4 text-right whitespace-nowrap">
                      <div
                        class="inline-flex items-center space-x-2"
                        phx-click="noop"
                        phx-stop-propagation
                      >
                        <button
                          type="button"
                          phx-click="view"
                          phx-value-id={b.id}
                          phx-stop-propagation
                          class="p-1 text-gray-400 hover:text-[#2E7D32] transition-colors
                                 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 rounded"
                          aria-label={"View #{b.id}"}
                        >
                          <!-- Eye icon -->
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
                            <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7S2 12 2 12Z"></path>
                            <circle cx="12" cy="12" r="3"></circle>
                          </svg>
                        </button>

                        <button
                          type="button"
                          phx-click="edit"
                          phx-value-id={b.id}
                          phx-stop-propagation
                          class="p-1 text-gray-400 hover:text-blue-600 transition-colors
                                 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 rounded"
                          aria-label={"Edit #{b.id}"}
                        >
                          <!-- Edit icon -->
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
                            <path d="M12 20h9"></path>
                            <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"></path>
                          </svg>
                        </button>
                      </div>
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

  # -------------------------
  # Events
  # -------------------------

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket), do: {:noreply, assign(socket, :q, q)}
  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  def handle_event("filter", _params, socket), do: {:noreply, socket}

  def handle_event("row_click", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/batches/#{id}")}
  end

  def handle_event("view", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/batches/#{id}")}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    # If you later add an edit screen, update this path.
    {:noreply, push_navigate(socket, to: ~p"/batches/#{id}")}
  end

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  # -------------------------
  # Function components
  # -------------------------

  attr :score, :integer, required: true

  def ripeness_badge(assigns) do
    {cls, label} = ripeness_meta(assigns.score)
    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      {@label} ({@score})
    </span>
    """
  end

  attr :status, :string, required: true

  def status_badge(assigns) do
    {cls, label} =
      case assigns.status do
        "Processed" -> {"bg-gray-50 text-gray-700 ring-gray-600/20", "Processed"}
        _ -> {"bg-green-50 text-green-700 ring-green-600/20", assigns.status || "Active"}
      end

    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      {@label}
    </span>
    """
  end

  # -------------------------
  # Pure helpers
  # -------------------------

  defp ripeness_meta(score) when is_integer(score) do
    cond do
      score <= 2 ->
        {"bg-gray-50 text-gray-700 ring-gray-600/20", "Unripe"}

      score <= 5 ->
        {"bg-yellow-50 text-yellow-700 ring-yellow-600/20", "Ripening"}

      true ->
        {"bg-green-50 text-green-700 ring-green-600/20", "Ready"}
    end
  end
end
