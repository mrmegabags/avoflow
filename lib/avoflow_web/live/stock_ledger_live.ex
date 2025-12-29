defmodule AvoflowWeb.StockLedgerLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar

  @page_size 5
  @verified_total 1247

  @impl true
  def mount(_params, _session, socket) do
    movements = [
      %{
        id: "MOV-2024-1247",
        timestamp: "2024-12-15 14:23:15",
        event_type: "PICK",
        sku: "LZ-500",
        lot: "LOT-090",
        from: "Purée Fridge",
        from_bin: "A-12",
        to: "Pick Zone",
        to_bin: nil,
        qty: 5,
        user: "J.Doe",
        device: "Scanner-03",
        approved: false,
        approver: nil,
        reason: nil,
        notes: nil,
        attachments: nil,
        order_id: nil,
        previous_hash: "7a8f3c2e1b9d...",
        current_hash: "9d4e6f1a2c8b...",
        signature: "valid"
      },
      %{
        id: "MOV-2024-1246",
        timestamp: "2024-12-15 14:15:42",
        event_type: "PACK",
        sku: "LZ-500",
        lot: "LOT-090",
        from: "Production",
        from_bin: nil,
        to: "Purée Fridge",
        to_bin: "A-12",
        qty: 20,
        user: "J.Doe",
        device: "Scanner-03",
        approved: false,
        approver: nil,
        reason: nil,
        notes: nil,
        attachments: nil,
        order_id: nil,
        previous_hash: "5c6d7e8f9a0b...",
        current_hash: "7a8f3c2e1b9d...",
        signature: "valid"
      },
      %{
        id: "MOV-2024-1245",
        timestamp: "2024-12-15 13:45:22",
        event_type: "ADJUST",
        sku: "SSB-200",
        lot: "LOT-089",
        from: "Purée Fridge",
        from_bin: "B-03",
        to: "Adjustment",
        to_bin: nil,
        qty: -3,
        user: "M.Lee",
        device: "Scanner-05",
        approved: true,
        approver: "S.Kim",
        reason: "DAMAGED",
        notes: "3 bottles leaked during transport",
        attachments: ["IMG_001.jpg", "IMG_002.jpg"],
        order_id: nil,
        previous_hash: "3b4c5d6e7f8a...",
        current_hash: "5c6d7e8f9a0b...",
        signature: "valid"
      },
      %{
        id: "MOV-2024-1244",
        timestamp: "2024-12-15 12:30:18",
        event_type: "SHIP",
        sku: "STD-300",
        lot: "LOT-088",
        from: "Pick Zone",
        from_bin: nil,
        to: "Shipped",
        to_bin: nil,
        qty: 8,
        user: "K.Ng",
        device: "Scanner-02",
        approved: false,
        approver: nil,
        reason: nil,
        notes: nil,
        attachments: nil,
        order_id: "ORD-5678",
        previous_hash: "1a2b3c4d5e6f...",
        current_hash: "3b4c5d6e7f8a...",
        signature: "valid"
      },
      %{
        id: "MOV-2024-1243",
        timestamp: "2024-12-15 11:00:05",
        event_type: "HOLD",
        sku: "GJ-206",
        lot: "LOT-087",
        from: "Purée Fridge",
        from_bin: "C-05",
        to: "QA Hold",
        to_bin: nil,
        qty: 12,
        user: "QA",
        device: "Terminal-01",
        approved: false,
        approver: nil,
        reason: "MICRO",
        notes: "Positive micro test on sample",
        attachments: nil,
        order_id: nil,
        previous_hash: "9f8e7d6c5b4a...",
        current_hash: "1a2b3c4d5e6f...",
        signature: "valid"
      }
    ]

    empty_filters = %{
      "date_from" => "",
      "date_to" => "",
      "event_type" => "",
      "sku" => "",
      "lot" => "",
      "user" => ""
    }

    socket =
      socket
      |> assign(
        # TopBar
        q: "",
        unread_count: 3,
        user_label: "John Doe",
        # Data
        movements: movements,
        selected_movement_id: nil,
        # Filters (draft -> apply)
        filters_draft: empty_filters,
        filters_applied: empty_filters,
        # Paging
        page: 1,
        page_size: @page_size,
        # Verification meta
        verified_total: @verified_total,
        last_check: "2 mins ago",
        # Derived
        movements_filtered: [],
        movements_page: [],
        total_filtered: 0,
        page_count: 1
      )
      |> recompute()

    {:ok, socket}
  end

  # =============================================================================
  # TopBar handlers (required)
  # =============================================================================

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(q: q, page: 1) |> recompute()}
  end

  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_profile", _params, socket), do: {:noreply, socket}

  # =============================================================================
  # Page interactions
  # =============================================================================

  @impl true
  def handle_event("filters_change", %{"filters" => params}, socket) do
    draft = Map.merge(socket.assigns.filters_draft, params)
    {:noreply, assign(socket, filters_draft: draft)}
  end

  def handle_event("apply_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(filters_applied: socket.assigns.filters_draft, page: 1)
     |> recompute()}
  end

  def handle_event("clear_filters", _params, socket) do
    empty = %{
      "date_from" => "",
      "date_to" => "",
      "event_type" => "",
      "sku" => "",
      "lot" => "",
      "user" => ""
    }

    {:noreply,
     socket |> assign(filters_draft: empty, filters_applied: empty, page: 1) |> recompute()}
  end

  def handle_event("select_movement", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_movement_id: id)}
  end

  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, selected_movement_id: nil)}
  end

  def handle_event("prev_page", _params, socket) do
    page = max(socket.assigns.page - 1, 1)
    {:noreply, socket |> assign(page: page) |> recompute()}
  end

  def handle_event("next_page", _params, socket) do
    page = min(socket.assigns.page + 1, socket.assigns.page_count)
    {:noreply, socket |> assign(page: page) |> recompute()}
  end

  # No-op actions for buttons that exist in the UI
  def handle_event("verify_now", _params, socket), do: {:noreply, socket}
  def handle_event("export_csv", _params, socket), do: {:noreply, socket}
  def handle_event("download_report", _params, socket), do: {:noreply, socket}
  def handle_event("view_in_explorer", _params, socket), do: {:noreply, socket}

  # =============================================================================
  # Render
  # =============================================================================

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(
        :selected_movement,
        selected_movement(assigns.movements, assigns.selected_movement_id)
      )

    ~H"""
    <div
      class={["", if(@selected_movement, do: "h-screen overflow-hidden", else: "")]}
      phx-window-keydown="close_drawer"
      phx-key="escape"
    >
      <main class="">
        <div class="">
          <!-- Header -->
          <div class="mb-6">
            <div class="flex items-center space-x-3 mb-2">
              <div class="w-10 h-10 bg-gradient-to-br from-gray-700 to-gray-900 rounded-lg flex items-center justify-center">
                <.sl_icon name="scroll-text" class="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 class="text-2xl font-bold text-gray-900">Stock Ledger</h1>
                <p class="text-gray-500 text-sm">Immutable audit trail of all stock movements</p>
              </div>
            </div>
          </div>
          
    <!-- Verification Status -->
          <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <.sl_icon name="shield" class="w-6 h-6 text-green-600" />
              <div>
                <p class="text-sm font-semibold text-green-900">Hash Chain Verified</p>
                <p class="text-xs text-green-700">
                  All {@verified_total} movements verified • Last check: {@last_check}
                </p>
              </div>
            </div>

            <.sl_button variant="secondary" phx-click="verify_now" type="button">
              <span class="inline-flex items-center gap-2">
                <.sl_icon name="check-circle" class="w-4 h-4" />
                <span>Verify Now</span>
              </span>
            </.sl_button>
          </div>
          
    <!-- Filters -->
          <.sl_card class="mb-6">
            <div class="flex items-center space-x-2 mb-4">
              <.sl_icon name="filter" class="w-5 h-5 text-gray-600" />
              <h3 class="font-semibold text-gray-900">Filters</h3>
            </div>

            <.form for={%{}} as={:filters} phx-change="filters_change">
              <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
                <.sl_field_input
                  type="date"
                  label="Date From"
                  name="filters[date_from]"
                  value={@filters_draft["date_from"]}
                />

                <.sl_field_input
                  type="date"
                  label="Date To"
                  name="filters[date_to]"
                  value={@filters_draft["date_to"]}
                />

                <.sl_field_select
                  label="Event Type"
                  name="filters[event_type]"
                  value={@filters_draft["event_type"]}
                  options={[
                    {"", "All Events"},
                    {"PICK", "Pick"},
                    {"PACK", "Pack"},
                    {"ADJUST", "Adjust"},
                    {"SHIP", "Ship"},
                    {"HOLD", "Hold"}
                  ]}
                />

                <.sl_field_input
                  type="text"
                  label="SKU"
                  name="filters[sku]"
                  placeholder="All SKUs"
                  value={@filters_draft["sku"]}
                />

                <.sl_field_input
                  type="text"
                  label="Lot"
                  name="filters[lot]"
                  placeholder="All Lots"
                  value={@filters_draft["lot"]}
                />

                <.sl_field_input
                  type="text"
                  label="User"
                  name="filters[user]"
                  placeholder="All Users"
                  value={@filters_draft["user"]}
                />
              </div>

              <div class="flex justify-between items-center mt-4 pt-4 border-t border-gray-200">
                <.sl_button variant="secondary" phx-click="clear_filters" type="button">
                  Clear Filters
                </.sl_button>

                <div class="flex space-x-2">
                  <.sl_button variant="secondary" phx-click="export_csv" type="button">
                    <span class="inline-flex items-center gap-2">
                      <.sl_icon name="download" class="w-4 h-4" />
                      <span>Export CSV</span>
                    </span>
                  </.sl_button>

                  <.sl_button variant="primary" phx-click="apply_filters" type="button">
                    Apply Filters
                  </.sl_button>
                </div>
              </div>
            </.form>
          </.sl_card>
          
    <!-- Movements Table -->
          <.sl_card>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead class="bg-gray-50 border-b-2 border-gray-200">
                  <tr>
                    <th class="text-left py-3 px-4 font-semibold text-gray-700">Timestamp</th>
                    <th class="text-left py-3 px-4 font-semibold text-gray-700">Event</th>
                    <th class="text-left py-3 px-4 font-semibold text-gray-700">SKU</th>
                    <th class="text-left py-3 px-4 font-semibold text-gray-700">Lot</th>
                    <th class="text-left py-3 px-4 font-semibold text-gray-700">From → To</th>
                    <th class="text-right py-3 px-4 font-semibold text-gray-700">Qty</th>
                    <th class="text-left py-3 px-4 font-semibold text-gray-700">User</th>
                    <th class="text-center py-3 px-4 font-semibold text-gray-700">Status</th>
                  </tr>
                </thead>

                <tbody class="divide-y divide-gray-100">
                  <%= for movement <- @movements_page do %>
                    <tr
                      phx-click="select_movement"
                      phx-value-id={movement.id}
                      class="hover:bg-gray-50 cursor-pointer transition-colors"
                    >
                      <td class="py-3 px-4 text-gray-600 font-mono text-xs">{movement.timestamp}</td>

                      <td class="py-3 px-4">
                        <span class={[
                          "px-2 py-1 rounded text-xs font-semibold",
                          event_type_color(movement.event_type)
                        ]}>
                          {movement.event_type}
                        </span>
                      </td>

                      <td class="py-3 px-4 font-medium text-gray-900">{movement.sku}</td>

                      <td class="py-3 px-4 font-mono text-xs text-gray-600">{movement.lot}</td>

                      <td class="py-3 px-4 text-xs text-gray-600">
                        <div class="flex items-center space-x-1">
                          <span>
                            {movement.from}{if movement.from_bin,
                              do: " (#{movement.from_bin})",
                              else: ""}
                          </span>
                          <span>→</span>
                          <span>
                            {movement.to}{if movement.to_bin, do: " (#{movement.to_bin})", else: ""}
                          </span>
                        </div>
                      </td>

                      <td class="py-3 px-4 text-right font-medium text-gray-900">
                        {if movement.qty > 0, do: "+", else: ""}{movement.qty}u
                      </td>

                      <td class="py-3 px-4 text-gray-600">{movement.user}</td>

                      <td class="py-3 px-4 text-center">
                        <%= if movement.approved do %>
                          <.sl_icon name="lock" class="w-4 h-4 text-orange-600 inline" />
                        <% else %>
                          <.sl_icon name="check-circle" class="w-4 h-4 text-green-600 inline" />
                        <% end %>
                      </td>
                    </tr>
                  <% end %>

                  <%= if @movements_page == [] do %>
                    <tr>
                      <td colspan="8" class="py-10 text-center text-sm text-gray-500">
                        No movements match the current filters.
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <div class="mt-4 pt-4 border-t border-gray-200 flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3 text-sm">
              <span class="text-gray-600">
                Showing {length(@movements_page)} of {@verified_total} movements • Hash chain:
                <span class="text-green-600 font-semibold">✓ VERIFIED</span>
              </span>

              <div class="flex space-x-2">
                <.sl_button
                  variant="secondary"
                  phx-click="prev_page"
                  disabled={@page <= 1}
                  type="button"
                >
                  Previous
                </.sl_button>

                <.sl_button
                  variant="secondary"
                  phx-click="next_page"
                  disabled={@page >= @page_count}
                  type="button"
                >
                  Next
                </.sl_button>
              </div>
            </div>
          </.sl_card>
          
    <!-- Detail Drawer -->
          <%= if @selected_movement do %>
            <div class="fixed inset-0 z-50 flex">
              <!-- Backdrop -->
              <button
                type="button"
                class="absolute inset-0 bg-black/50"
                phx-click="close_drawer"
                aria-label="Close drawer"
              >
              </button>
              
    <!-- Drawer panel -->
              <div class="relative ml-auto h-full w-full sm:max-w-2xl bg-white shadow-2xl overflow-y-auto overscroll-contain">
                <div class="p-6 pb-10">
                  <!-- Header -->
                  <div class="flex items-start justify-between mb-6">
                    <div>
                      <h2 class="text-xl font-bold text-gray-900">Movement Detail</h2>
                      <p class="text-sm text-gray-500 font-mono mt-1">{@selected_movement.id}</p>
                    </div>

                    <button
                      type="button"
                      phx-click="close_drawer"
                      class="text-gray-400 hover:text-gray-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 rounded"
                      aria-label="Close"
                    >
                      ✕
                    </button>
                  </div>
                  
    <!-- Event Type Badge -->
                  <div class="mb-6">
                    <span class={[
                      "inline-flex items-center space-x-2 px-3 py-2 rounded-lg text-sm font-semibold",
                      event_type_color(@selected_movement.event_type)
                    ]}>
                      <.sl_icon name={event_type_icon(@selected_movement.event_type)} class="w-4 h-4" />
                      <span>{@selected_movement.event_type}</span>
                    </span>
                    <p class="text-xs text-gray-500 mt-2">{@selected_movement.timestamp}</p>
                  </div>
                  
    <!-- Movement Details -->
                  <.sl_card class="mb-6">
                    <h3 class="text-sm font-semibold text-gray-900 mb-4 flex items-center space-x-2">
                      <.sl_icon name="package" class="w-4 h-4" />
                      <span>Movement Details</span>
                    </h3>

                    <div class="space-y-3 text-sm">
                      <div class="flex justify-between">
                        <span class="text-gray-600">SKU:</span>
                        <span class="font-semibold text-gray-900">{@selected_movement.sku}</span>
                      </div>

                      <div class="flex justify-between">
                        <span class="text-gray-600">Lot:</span>
                        <span class="font-mono text-gray-900">{@selected_movement.lot}</span>
                      </div>

                      <div class="flex justify-between">
                        <span class="text-gray-600">From Location:</span>
                        <span class="text-gray-900">
                          {@selected_movement.from}{if @selected_movement.from_bin,
                            do: ", Bin #{@selected_movement.from_bin}",
                            else: ""}
                        </span>
                      </div>

                      <div class="flex justify-between">
                        <span class="text-gray-600">To Location:</span>
                        <span class="text-gray-900">
                          {@selected_movement.to}{if @selected_movement.to_bin,
                            do: ", Bin #{@selected_movement.to_bin}",
                            else: ""}
                        </span>
                      </div>

                      <div class="flex justify-between pt-3 border-t border-gray-200">
                        <span class="text-gray-600">Quantity:</span>
                        <span class="font-bold text-gray-900">
                          {if @selected_movement.qty > 0, do: "+", else: ""}{@selected_movement.qty} units
                        </span>
                      </div>
                    </div>
                  </.sl_card>
                  
    <!-- User & Device -->
                  <.sl_card class="mb-6">
                    <h3 class="text-sm font-semibold text-gray-900 mb-4 flex items-center space-x-2">
                      <.sl_icon name="user" class="w-4 h-4" />
                      <span>User & Device</span>
                    </h3>

                    <div class="space-y-3 text-sm">
                      <div class="flex justify-between">
                        <span class="text-gray-600">Initiated By:</span>
                        <span class="font-semibold text-gray-900">{@selected_movement.user}</span>
                      </div>

                      <div class="flex justify-between">
                        <span class="text-gray-600">Device:</span>
                        <span class="text-gray-900">{@selected_movement.device}</span>
                      </div>

                      <%= if @selected_movement.approved and @selected_movement.approver do %>
                        <div class="flex justify-between pt-3 border-t border-gray-200">
                          <span class="text-gray-600">Approved By:</span>
                          <span class="font-semibold text-gray-900">
                            {@selected_movement.approver}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </.sl_card>
                  
    <!-- Reason & Attachments -->
                  <%= if @selected_movement.reason || @selected_movement.notes || @selected_movement.attachments do %>
                    <.sl_card class="mb-6">
                      <h3 class="text-sm font-semibold text-gray-900 mb-4 flex items-center space-x-2">
                        <.sl_icon name="file-text" class="w-4 h-4" />
                        <span>Reason & Attachments</span>
                      </h3>

                      <%= if @selected_movement.reason do %>
                        <div class="mb-3">
                          <span class="text-xs text-gray-600">Reason Code:</span>
                          <.sl_badge variant="warning" class="ml-2">
                            {@selected_movement.reason}
                          </.sl_badge>
                        </div>
                      <% end %>

                      <%= if @selected_movement.notes do %>
                        <div class="mb-3">
                          <p class="text-sm text-gray-700 bg-gray-50 p-3 rounded border border-gray-200">
                            "{@selected_movement.notes}"
                          </p>
                        </div>
                      <% end %>

                      <%= if is_list(@selected_movement.attachments) do %>
                        <div>
                          <p class="text-xs text-gray-600 mb-2">Attachments:</p>

                          <div class="space-y-2">
                            <%= for file <- @selected_movement.attachments do %>
                              <div class="flex items-center space-x-2 text-sm">
                                <.sl_icon name="image" class="w-4 h-4 text-gray-400" />
                                <span class="text-gray-700">{file}</span>
                                <button
                                  type="button"
                                  class="text-blue-600 hover:text-blue-800 text-xs"
                                >
                                  View
                                </button>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </.sl_card>
                  <% end %>
                  
    <!-- Cryptographic Verification -->
                  <.sl_card class="bg-gray-50">
                    <h3 class="text-sm font-semibold text-gray-900 mb-4 flex items-center space-x-2">
                      <.sl_icon name="shield" class="w-4 h-4" />
                      <span>Cryptographic Verification</span>
                    </h3>

                    <div class="space-y-3 text-xs">
                      <div>
                        <span class="text-gray-600">Previous Hash:</span>
                        <code class="block mt-1 font-mono text-gray-900 bg-white p-2 rounded border border-gray-200 overflow-x-auto">
                          {@selected_movement.previous_hash}
                        </code>
                      </div>

                      <div>
                        <span class="text-gray-600">Current Hash:</span>
                        <code class="block mt-1 font-mono text-gray-900 bg-white p-2 rounded border border-gray-200 overflow-x-auto">
                          {@selected_movement.current_hash}
                        </code>
                      </div>

                      <div class="pt-3 border-t border-gray-300">
                        <div class="flex items-center space-x-2">
                          <.sl_icon name="check-circle" class="w-4 h-4 text-green-600" />
                          <span class="font-semibold text-green-900">
                            Signature: VALID (RSA-2048)
                          </span>
                        </div>
                        <p class="text-gray-600 mt-1">Signed By: System Key (inventory-prod-01)</p>
                      </div>

                      <div class="pt-3 border-t border-gray-300">
                        <div class="flex items-center space-x-2">
                          <.sl_icon name="check-circle" class="w-4 h-4 text-green-600" />
                          <span class="font-semibold text-green-900">Hash Chain: INTACT</span>
                        </div>
                        <p class="text-gray-600 mt-1">
                          Verified against previous {@verified_total} movements
                        </p>
                      </div>
                    </div>
                  </.sl_card>
                  
    <!-- Actions -->
                  <div class="mt-6 flex flex-col sm:flex-row sm:space-x-3 gap-3 sm:gap-0">
                    <.sl_button
                      variant="secondary"
                      class="flex-1"
                      phx-click="view_in_explorer"
                      type="button"
                    >
                      <span class="inline-flex items-center gap-2">
                        <.sl_icon name="external-link" class="w-4 h-4" />
                        <span>View in Explorer</span>
                      </span>
                    </.sl_button>

                    <.sl_button
                      variant="secondary"
                      class="flex-1"
                      phx-click="download_report"
                      type="button"
                    >
                      <span class="inline-flex items-center gap-2">
                        <.sl_icon name="download" class="w-4 h-4" />
                        <span>Download Report</span>
                      </span>
                    </.sl_button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  # =============================================================================
  # Local components (prefixed to avoid CoreComponents conflicts)
  # =============================================================================

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def sl_card(assigns) do
    ~H"""
    <div class={["bg-white border border-gray-200 rounded-xl shadow-sm p-6", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :variant, :string, default: "neutral"
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def sl_badge(assigns) do
    {bg, text, ring} =
      case assigns.variant do
        "warning" -> {"bg-amber-50", "text-amber-700", "ring-amber-200"}
        "success" -> {"bg-green-50", "text-green-700", "ring-green-200"}
        "danger" -> {"bg-red-50", "text-red-700", "ring-red-200"}
        _ -> {"bg-gray-100", "text-gray-700", "ring-gray-200"}
      end

    assigns = assign(assigns, bg: bg, text: text, ring: ring)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset",
      @bg,
      @text,
      @ring,
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :variant, :string, default: "primary"
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :type, :string, default: "button"
  attr :rest, :global, include: ~w(phx-click)

  slot :inner_block, required: true

  def sl_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap transition-colors " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
        "disabled:opacity-50 disabled:cursor-not-allowed"

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm hover:bg-gray-200"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"
        _ -> "bg-[#2E7D32] text-white rounded-full h-9 px-4 text-sm hover:brightness-95"
      end

    assigns = assign(assigns, :btn_class, Enum.join([base, variant, assigns.class || ""], " "))

    ~H"""
    <button type={@type} class={@btn_class} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: nil
  attr :value, :string, default: ""
  attr :class, :string, default: nil

  def sl_field_input(assigns) do
    ~H"""
    <div class={@class}>
      <label class="block text-xs font-medium text-gray-700 mb-1">{@label}</label>
      <input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
      />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :options, :list, required: true
  attr :class, :string, default: nil

  def sl_field_select(assigns) do
    ~H"""
    <div class={@class}>
      <label class="block text-xs font-medium text-gray-700 mb-1">{@label}</label>
      <select
        name={@name}
        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
      >
        <%= for {val, label} <- @options do %>
          <option value={val} selected={@value == val}>{label}</option>
        <% end %>
      </select>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "w-5 h-5"

  def sl_icon(assigns) do
    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <%= case @name do %>
        <% "scroll-text" -> %>
          <path d="M8 21h8"></path>
          <path d="M8 7h8"></path>
          <path d="M8 12h8"></path>
          <path d="M8 17h8"></path>
          <path d="M6 3h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8l-4-4V5a2 2 0 0 1 2-2Z"></path>
        <% "shield" -> %>
          <path d="M12 2l8 4v6c0 5-3.5 9.5-8 10-4.5-.5-8-5-8-10V6l8-4Z"></path>
        <% "check-circle" -> %>
          <path d="M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z"></path>
          <path d="m9 12 2 2 4-4"></path>
        <% "filter" -> %>
          <path d="M22 3H2l8 9v7l4 2v-9l8-9Z"></path>
        <% "download" -> %>
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
          <path d="M7 10l5 5 5-5"></path>
          <path d="M12 15V3"></path>
        <% "package" -> %>
          <path d="M16.5 9.4 7.5 4.2"></path>
          <path d="M21 16V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z">
          </path>
          <path d="M3.3 7.6 12 12l8.7-4.4"></path>
          <path d="M12 22V12"></path>
        <% "alert-circle" -> %>
          <path d="M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20Z"></path>
          <path d="M12 8v4"></path>
          <path d="M12 16h.01"></path>
        <% "lock" -> %>
          <path d="M19 11H5"></path>
          <path d="M17 11V7a5 5 0 0 0-10 0v4"></path>
          <path d="M17 11v10H7V11"></path>
        <% "map-pin" -> %>
          <path d="M12 21s8-4.5 8-11a8 8 0 1 0-16 0c0 6.5 8 11 8 11Z"></path>
          <circle cx="12" cy="10" r="3"></circle>
        <% "user" -> %>
          <path d="M20 21a8 8 0 0 0-16 0"></path>
          <circle cx="12" cy="7" r="4"></circle>
        <% "file-text" -> %>
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
          <path d="M14 2v6h6"></path>
          <path d="M16 13H8"></path>
          <path d="M16 17H8"></path>
          <path d="M10 9H8"></path>
        <% "image" -> %>
          <rect x="3" y="3" width="18" height="18" rx="2"></rect>
          <circle cx="8.5" cy="8.5" r="1.5"></circle>
          <path d="M21 15l-5-5L5 21"></path>
        <% "external-link" -> %>
          <path d="M15 3h6v6"></path>
          <path d="M10 14 21 3"></path>
          <path d="M21 14v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h7"></path>
        <% _ -> %>
          <path d="M12 12h.01"></path>
      <% end %>
    </svg>
    """
  end

  # =============================================================================
  # Derived state
  # =============================================================================

  defp recompute(socket) do
    filtered =
      socket.assigns.movements
      |> Enum.filter(&movement_matches?(&1, socket.assigns.filters_applied))
      |> Enum.filter(&matches_topbar_q?(&1, socket.assigns.q))

    total_filtered = length(filtered)

    page_count =
      case total_filtered do
        0 -> 1
        n -> div(n + socket.assigns.page_size - 1, socket.assigns.page_size)
      end

    page = min(max(socket.assigns.page, 1), page_count)
    start_idx = (page - 1) * socket.assigns.page_size
    page_rows = Enum.slice(filtered, start_idx, socket.assigns.page_size)

    assign(socket,
      movements_filtered: filtered,
      movements_page: page_rows,
      total_filtered: total_filtered,
      page_count: page_count,
      page: page
    )
  end

  defp selected_movement(_movements, nil), do: nil
  defp selected_movement(movements, id), do: Enum.find(movements, &(&1.id == id))

  # =============================================================================
  # Filtering helpers
  # =============================================================================

  defp movement_matches?(m, filters) do
    date_from = Map.get(filters, "date_from", "")
    date_to = Map.get(filters, "date_to", "")
    event_type = Map.get(filters, "event_type", "")
    sku = Map.get(filters, "sku", "")
    lot = Map.get(filters, "lot", "")
    user = Map.get(filters, "user", "")

    ts = parse_ts(m.timestamp)
    ts_date = if ts, do: NaiveDateTime.to_date(ts), else: nil

    date_from_ok =
      case {String.trim(date_from), ts_date} do
        {"", _} -> true
        {iso, %Date{} = d} -> d >= parse_date(iso)
        _ -> true
      end

    date_to_ok =
      case {String.trim(date_to), ts_date} do
        {"", _} -> true
        {iso, %Date{} = d} -> d <= parse_date(iso)
        _ -> true
      end

    event_ok = event_type == "" or m.event_type == event_type
    sku_ok = sku == "" or contains_ci?(m.sku, sku)
    lot_ok = lot == "" or contains_ci?(m.lot, lot)
    user_ok = user == "" or contains_ci?(m.user, user)

    date_from_ok and date_to_ok and event_ok and sku_ok and lot_ok and user_ok
  end

  defp matches_topbar_q?(_m, q) when q in [nil, ""], do: true

  defp matches_topbar_q?(m, q) do
    q = String.trim(q)

    if q == "" do
      true
    else
      hay =
        [
          m.id,
          m.timestamp,
          m.event_type,
          m.sku,
          m.lot,
          m.from,
          m.from_bin,
          m.to,
          m.to_bin,
          m.user,
          m.device,
          m.order_id
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")

      contains_ci?(hay, q)
    end
  end

  defp contains_ci?(haystack, needle) when is_binary(haystack) and is_binary(needle) do
    String.contains?(String.downcase(haystack), String.downcase(String.trim(needle)))
  end

  defp parse_date(iso) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
  end

  defp parse_ts(ts) when is_binary(ts) do
    iso = String.replace(ts, " ", "T")

    case NaiveDateTime.from_iso8601(iso) do
      {:ok, ndt} -> ndt
      _ -> nil
    end
  end

  # =============================================================================
  # Event type config
  # =============================================================================

  defp event_type_color(type) do
    case type do
      "PICK" -> "bg-blue-100 text-blue-800"
      "PACK" -> "bg-green-100 text-green-800"
      "ADJUST" -> "bg-orange-100 text-orange-800"
      "SHIP" -> "bg-purple-100 text-purple-800"
      "HOLD" -> "bg-red-100 text-red-800"
      "TRANSFER" -> "bg-gray-100 text-gray-800"
      "RECEIVE" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp event_type_icon(type) do
    case type do
      "ADJUST" -> "alert-circle"
      "HOLD" -> "lock"
      "TRANSFER" -> "map-pin"
      _ -> "package"
    end
  end
end
