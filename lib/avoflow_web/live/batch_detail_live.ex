defmodule AvoflowWeb.BatchesDetailLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar
  import Phoenix.Component

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    batch = %{
      id: id || "B-009",
      supplier_name: "Avocorp",
      variety: "Hass",
      date_received: "2023-10-24",
      quantity_kg: 450,
      ripeness_score: 4,
      defects_percentage: 2.5,
      status: "Ripening",
      notes: "Fruit looks good, slight variation in size.",
      history: [
        %{date: "2023-10-24 08:00", action: "Received", user: "John Doe"},
        %{date: "2023-10-25 09:00", action: "Ripeness Check (Score: 2)", user: "Jane Smith"},
        %{date: "2023-10-26 09:00", action: "Ripeness Check (Score: 4)", user: "Jane Smith"}
      ]
    }

    {:ok,
     assign(socket,
       page_title: "Batch #{batch.id}",
       q: "",
       user_label: "User",
       unread_count: 0,
       batch: batch
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="">
      <div class="">
        <!-- Back -->
        <.link
          navigate={~p"/batches"}
          class="inline-flex items-center text-sm text-gray-500 hover:text-gray-900 mb-4 transition-colors"
        >
          <!-- ArrowLeft icon -->
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-4 h-4 mr-1"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
          Back to Batches
        </.link>
        
    <!-- Header -->
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-4 mb-6">
          <div>
            <div class="flex items-center gap-3 mb-1">
              <h1 class="text-2xl font-bold text-gray-900">Batch {@batch.id}</h1>
              <.ripeness_badge score={@batch.ripeness_score} />
            </div>
            <p class="text-gray-500">
              Received on {@batch.date_received} • {@batch.variety}
            </p>
          </div>

          <div class="flex flex-row gap-3 sm:justify-end">
            <button
              type="button"
              phx-click="print_label"
              class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-full text-sm font-medium
                     bg-gray-100 text-gray-900 hover:bg-gray-200
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
            >
              <!-- Printer icon -->
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
                <polyline points="6 9 6 2 18 2 18 9"></polyline>
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2">
                </path>
                <rect x="6" y="14" width="12" height="8"></rect>
              </svg>
              Print Label
            </button>

            <button
              type="button"
              phx-click="update_status"
              class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-full text-sm font-medium
                     bg-[#2E7D32] text-white hover:brightness-95
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
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
              Update Status
            </button>
          </div>
        </div>
        
    <!-- Content -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Left -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Batch Information -->
            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Batch Information</h3>
              </div>
              <div class="p-5">
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Supplier</h4>
                    <p class="text-gray-900 font-medium">{@batch.supplier_name}</p>
                  </div>

                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Quantity</h4>
                    <p class="text-gray-900 font-medium">{@batch.quantity_kg} kg</p>
                  </div>

                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Defects</h4>
                    <p class="text-gray-900">{@batch.defects_percentage}%</p>
                  </div>

                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Current Status</h4>
                    <p class="text-gray-900">{@batch.status}</p>
                  </div>

                  <div class="sm:col-span-2">
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Notes</h4>
                    <p class="text-gray-700 bg-gray-50 p-3 rounded-md text-sm">
                      {@batch.notes}
                    </p>
                  </div>
                </div>
              </div>
            </section>
            
    <!-- Ripeness Progress -->
            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Ripeness Progress</h3>
              </div>
              <div class="p-5">
                <div class="mb-6">
                  <div class="flex justify-between mb-2">
                    <span class="text-sm font-medium text-gray-700">
                      Current Score: {@batch.ripeness_score}/6
                    </span>
                    <span class="text-sm text-gray-500">Target: 5-6</span>
                  </div>

                  <.progress_bar value={@batch.ripeness_score} max={6} />

                  <div class="flex justify-between mt-2 text-xs text-gray-400">
                    <span>1 (Hard)</span>
                    <span>3 (Breaking)</span>
                    <span>6 (Overripe)</span>
                  </div>
                </div>
              </div>
            </section>
          </div>
          
    <!-- Right -->
          <div class="lg:col-span-1">
            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Activity Log</h3>
              </div>
              <div class="p-5">
                <div class="space-y-6">
                  <%= for {event, idx} <- Enum.with_index(@batch.history) do %>
                    <div class="relative pl-4 border-l-2 border-gray-100">
                      <div class="absolute -left-[5px] top-1.5 w-2.5 h-2.5 rounded-full bg-gray-300 ring-4 ring-white">
                      </div>

                      <p class="text-sm font-medium text-gray-900">{event.action}</p>

                      <div class="flex justify-between mt-1">
                        <span class="text-xs text-gray-500">{event.date}</span>
                        <span class="text-xs text-gray-400">{event.user}</span>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>
    </main>
    """
  end

  # -------------------------
  # Events (no-op placeholders)
  # -------------------------

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket), do: {:noreply, assign(socket, :q, q)}
  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  def handle_event("print_label", _params, socket), do: {:noreply, socket}
  def handle_event("update_status", _params, socket), do: {:noreply, socket}

  # -------------------------
  # Function components
  # -------------------------

  attr :score, :integer, required: true

  def ripeness_badge(assigns) do
    {cls, label} = ripeness_meta(assigns.score)
    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      {@label}
    </span>
    """
  end

  attr :value, :integer, required: true
  attr :max, :integer, required: true

  def progress_bar(assigns) do
    maxv = if assigns.max in [0, nil], do: 1, else: assigns.max
    pct = assigns.value / maxv * 100
    pct = pct |> min(100) |> max(0)

    assigns = assign(assigns, pct: pct)

    ~H"""
    <div class="h-3 w-full rounded-full bg-gray-100 overflow-hidden">
      <div class="h-full bg-[#2E7D32] rounded-full transition-all" style={"width: #{@pct}%;"}></div>
    </div>
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
