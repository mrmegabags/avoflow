defmodule AvoflowWeb.FinishedGoodsDashboardLive do
  use AvoflowWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    # SKU catalog (single source of truth for display)
    skus = [
      %{code: "LZ-500", name: "Large ziplock", container: "Ziplock", volume_ml: 500},
      %{code: "SSB-200", name: "Small sauce bottle", container: "Bottle", volume_ml: 200},
      %{code: "STD-300", name: "Standard sauce bottle", container: "Bottle", volume_ml: 300},
      %{code: "SG-50", name: "Small shot glass", container: "Cup", volume_ml: 50},
      %{code: "GJ-206", name: "Glass jar", container: "Jar", volume_ml: 206}
    ]

    # Expiring lots + status field (days computed from expiry)
    expiring_lots =
      [
        %{
          id: "LOT-089",
          sku: "LZ-500",
          expiry: "2024-12-20",
          qty: 23,
          location: "Fridge-A",
          status: "OK"
        },
        %{
          id: "LOT-087",
          sku: "SSB-200",
          expiry: "2024-12-19",
          qty: 45,
          location: "Fridge-B",
          status: "OK"
        },
        %{
          id: "LOT-085",
          sku: "STD-300",
          expiry: "2024-12-21",
          qty: 12,
          location: "Fridge-A",
          status: "OK"
        },
        %{
          id: "LOT-083",
          sku: "GJ-206",
          expiry: "2024-12-18",
          qty: 8,
          location: "Quarantine",
          status: "HOLD"
        }
      ]
      |> Enum.map(&normalize_lot/1)
      |> Enum.sort_by(& &1.days)

    suspicious_activity_raw = [
      %{
        type: "after-hours",
        user: "J.Doe",
        time: "2:34 AM",
        detail: "-15 units LZ-500",
        severity: "high"
      },
      %{
        type: "repeated-voids",
        user: "M.Smith",
        time: "Shift 2",
        detail: "3 voids in 4 hours",
        severity: "medium"
      },
      %{
        type: "location-mismatch",
        user: "Scanner-05",
        time: "14:20",
        detail: "Device in Zone-B, stock in Zone-A",
        severity: "medium"
      }
    ]

    recent_activity_raw = [
      %{time: "2 mins ago", action: "Packed 20x LZ-500", user: "J.Doe"},
      %{time: "5 mins ago", action: "Shipped ORD-5678", user: "K.Ng"},
      %{time: "12 mins ago", action: "Hold placed on LOT-087", user: "QA"},
      %{time: "15 mins ago", action: "Adjustment approved", user: "S.Kim"}
    ]

    location_stock = [
      %{
        location: "Purée Fridge",
        on_hand: 1245,
        available: 890,
        reserved: 45,
        on_hold: 12,
        expiring: 23
      },
      %{
        location: "Purée Freezer",
        on_hand: 892,
        available: 892,
        reserved: 0,
        on_hold: 0,
        expiring: 0
      },
      %{
        location: "Dispatch Chiller",
        on_hand: 456,
        available: 321,
        reserved: 111,
        on_hold: 24,
        expiring: 45
      },
      %{
        location: "Returns Quarantine",
        on_hand: 89,
        available: 0,
        reserved: 0,
        on_hold: 89,
        expiring: 12
      }
    ]

    # SKU-level inventory (kept consistent with expiring lots quantities)
    sku_stock = [
      %{
        sku: "LZ-500",
        on_hand: 980,
        available: 720,
        reserved: 45,
        on_hold: 12,
        expiring_7d: 23,
        shrinkage_mtd: 6
      },
      %{
        sku: "SSB-200",
        on_hand: 745,
        available: 590,
        reserved: 55,
        on_hold: 0,
        expiring_7d: 45,
        shrinkage_mtd: 3
      },
      %{
        sku: "STD-300",
        on_hand: 612,
        available: 508,
        reserved: 56,
        on_hold: 33,
        expiring_7d: 12,
        shrinkage_mtd: 2
      },
      %{
        sku: "SG-50",
        on_hand: 0,
        available: 0,
        reserved: 0,
        on_hold: 0,
        expiring_7d: 0,
        shrinkage_mtd: 0
      },
      %{
        sku: "GJ-206",
        on_hand: 510,
        available: 285,
        reserved: 0,
        on_hold: 0,
        expiring_7d: 9,
        shrinkage_mtd: 1
      }
    ]

    suspicious_activity =
      Enum.map(suspicious_activity_raw, &Map.put(&1, :sku, detect_sku(&1.detail, skus)))

    recent_activity =
      Enum.map(recent_activity_raw, &Map.put(&1, :sku, detect_sku(&1.action, skus)))

    socket =
      socket
      |> assign(
        # TopBar
        q: "",
        unread_count: 3,
        user_label: "John Doe",
        # Data
        skus: skus,
        sku_stock: sku_stock,
        expiring_lots: expiring_lots,
        suspicious_activity: suspicious_activity,
        recent_activity: recent_activity,
        location_stock: location_stock,
        # UI state
        selected_sku: "ALL",
        open_menu_id: nil,
        # Action drawer state
        action_open: false,
        action_kind: nil,
        action_scope: nil,
        action_target: nil,
        action_qty: "",
        action_dest: "Dispatch Chiller",
        action_reason: "",
        action_note: "",
        # Action preview / validation state
        action_preview_qty: 0,
        action_preview_qty_label: "0 u",
        action_qty_hint: "",
        action_qty_placeholder: "",
        action_reason_hint: "",
        action_reason_placeholder: "",
        action_warning: nil,
        action_preview_effect: nil,
        action_error: nil,
        action_can_confirm: false
      )
      |> recompute()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected =
      case Map.get(params, "sku") do
        nil -> socket.assigns.selected_sku
        "" -> "ALL"
        sku -> sku
      end

    selected =
      if selected == "ALL" or sku_in_catalog?(selected, socket.assigns.skus),
        do: selected,
        else: "ALL"

    socket =
      socket
      |> assign(selected_sku: selected)
      |> recompute()

    {:noreply, socket}
  end

  # =============================================================================
  # TopBar handlers
  # =============================================================================

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(q: q) |> recompute()}
  end

  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_profile", _params, socket), do: {:noreply, socket}

  # =============================================================================
  # Interaction flow: menu -> drawer -> confirm
  # =============================================================================

  def handle_event("select_sku", %{"sku" => sku}, socket) do
    sku = if sku == "ALL" or sku_in_catalog?(sku, socket.assigns.skus), do: sku, else: "ALL"
    {:noreply, push_patch(socket, to: ~p"/finished-goods?#{%{sku: sku}}")}
  end

  def handle_event("toggle_row_menu", %{"id" => id}, socket) do
    open = socket.assigns.open_menu_id
    {:noreply, assign(socket, open_menu_id: if(open == id, do: nil, else: id))}
  end

  def handle_event("close_row_menu", _params, socket) do
    {:noreply, assign(socket, open_menu_id: nil)}
  end

  def handle_event("open_action", %{"kind" => kind, "scope" => scope, "target" => target}, socket) do
    {default_qty, default_reason} = default_action_fields(kind)

    socket =
      socket
      |> assign(
        open_menu_id: nil,
        action_open: true,
        action_kind: kind,
        action_scope: scope,
        action_target: target,
        action_qty: default_qty,
        action_reason: default_reason,
        action_note: ""
      )
      |> recompute_action_preview()

    {:noreply, socket}
  end

  def handle_event("close_action", _params, socket), do: {:noreply, clear_action(socket)}

  def handle_event("action_change", %{"action" => params}, socket) do
    socket =
      socket
      |> assign(
        action_qty: Map.get(params, "qty", socket.assigns.action_qty),
        action_dest: Map.get(params, "dest", socket.assigns.action_dest),
        action_reason: Map.get(params, "reason", socket.assigns.action_reason),
        action_note: Map.get(params, "note", socket.assigns.action_note)
      )
      |> recompute_action_preview()

    {:noreply, socket}
  end

  def handle_event("confirm_action", _params, socket) do
    case apply_action(socket) do
      {:ok, socket} ->
        socket =
          socket
          |> put_flash(:info, "Action recorded.")
          |> clear_action()
          |> recompute()

        {:noreply, socket}

      {:error, msg, socket} ->
        {:noreply, socket |> put_flash(:error, msg) |> recompute_action_preview()}
    end
  end

  # =============================================================================
  # Render
  # =============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="" phx-window-keydown="close_action" phx-key="escape">
      <main class="">
        <div class="">
          <div class="mb-8 flex flex-col sm:flex-row sm:justify-between sm:items-end gap-4">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Finished Goods Inventory</h1>
              <p class="text-gray-500 mt-1">
                Daily operations: ship, hold/release, sample, dispose, and monitor expiry risk
              </p>
              <p class="text-xs text-gray-500 mt-1">
                Search filters both SKUs and Lots. Press
                <span class="font-semibold text-gray-700">Esc</span>
                to close the drawer.
              </p>
            </div>
          </div>
          
    <!-- Workflows / Navigation -->
          <div class="mb-6">
            <div class="flex flex-wrap gap-2">
              <.fg_button variant="primary" phx-click={JS.navigate(~p"/finished-goods/pack")}>
                <.fg_svg_icon name="package" class="w-4 h-4 mr-2" /> Pack
              </.fg_button>

              <.fg_button variant="secondary" phx-click={JS.navigate(~p"/finished-goods/fulfill")}>
                <.fg_svg_icon name="truck" class="w-4 h-4 mr-2" /> Fulfill (Pick/Pack/Ship)
              </.fg_button>

              <.fg_button variant="secondary" phx-click={JS.navigate(~p"/finished-goods/shipped")}>
                <.fg_svg_icon name="check-circle" class="w-4 h-4 mr-2" /> Shipped Orders
              </.fg_button>

              <.fg_button variant="secondary" phx-click={JS.navigate(~p"/finished-goods/adjustments")}>
                <.fg_svg_icon name="bar-chart" class="w-4 h-4 mr-2" /> Adjustments
              </.fg_button>
            </div>

            <p class="mt-2 text-xs text-gray-500">
              Tip: Order- and adjustment-specific pages (the <span class="font-semibold">:show</span>
              routes) are typically reached from their index lists.
            </p>
          </div>
          
    <!-- SKU scope selector -->
          <div class="mb-6">
            <div class="flex flex-wrap gap-2">
              <.sku_chip sku="ALL" label="All SKUs" selected={@selected_sku == "ALL"} />
              <%= for sku <- @skus do %>
                <.sku_chip sku={sku.code} label={sku.code} selected={@selected_sku == sku.code} />
              <% end %>
            </div>

            <p class="mt-2 text-xs text-gray-500">
              Scope:
              <span class="font-semibold text-gray-700">
                {if @selected_sku == "ALL", do: "All SKUs", else: @selected_sku}
              </span>
              <%= if @selected_sku != "ALL" do %>
                • <span class="text-gray-500">{sku_label(@skus, @selected_sku)}</span>
              <% end %>
            </p>
          </div>
          
    <!-- KPI Cards -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
            <.stat_card
              title="On-Hand"
              value={"#{format_int(@kpi.on_hand)} units"}
              icon="package"
              color="bg-blue-50 text-blue-600"
            />
            <.stat_card
              title="Available"
              value={"#{format_int(@kpi.available)} units"}
              icon="check-circle"
              color="bg-green-50 text-green-600"
            />
            <.stat_card
              title="Reserved"
              value={"#{format_int(@kpi.reserved)} units"}
              icon="lock"
              color="bg-purple-50 text-purple-600"
            />
            <.stat_card
              title="Expiring (7d)"
              value={"#{format_int(@kpi.expiring_7d)} units"}
              icon="clock"
              color="bg-orange-50 text-orange-600"
            />
            <.stat_card
              title="On Hold"
              value={"#{format_int(@kpi.on_hold)} units"}
              icon="shield-alert"
              color="bg-yellow-50 text-yellow-600"
            />
            <.stat_card
              title="Shrinkage (MTD)"
              value={"#{format_int(@kpi.shrinkage_mtd)} units"}
              icon="trending-down"
              color="bg-red-50 text-red-600"
            />
          </div>
          
    <!-- SKU Summary -->
          <.fg_card title="📦 SKU Summary" class="mb-8">
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-200">
                    <th class="text-left py-3 px-4 font-semibold text-gray-600">SKU</th>
                    <th class="text-left py-3 px-4 font-semibold text-gray-600">Description</th>
                    <th class="text-right py-3 px-4 font-semibold text-gray-600">Available</th>
                    <th class="text-right py-3 px-4 font-semibold text-gray-600">On-Hold</th>
                    <th class="text-right py-3 px-4 font-semibold text-gray-600">Expiring</th>
                    <th class="text-right py-3 px-4 font-semibold text-gray-600">Risk</th>
                    <th class="text-right py-3 px-4 font-semibold text-gray-600">Actions</th>
                  </tr>
                </thead>

                <tbody class="divide-y divide-gray-100">
                  <%= for row <- @sku_rows do %>
                    <% menu_id = "sku:" <> row.sku %>
                    <tr class="hover:bg-gray-50">
                      <td class="py-3 px-4 font-medium text-gray-900">
                        <button
                          type="button"
                          class="text-left hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 rounded"
                          phx-click="select_sku"
                          phx-value-sku={row.sku}
                        >
                          {row.sku}
                        </button>
                      </td>

                      <td class="py-3 px-4 text-gray-600">{row.label}</td>
                      <td class="py-3 px-4 text-right text-green-600 font-medium">
                        {format_int(row.available)}u
                      </td>
                      <td class="py-3 px-4 text-right text-yellow-600">{format_int(row.on_hold)}u</td>
                      <td class="py-3 px-4 text-right text-orange-600">
                        {format_int(row.expiring_7d)}u
                      </td>

                      <td class="py-3 px-4 text-right">
                        <.fg_badge variant={row.risk_badge}>{row.risk_label}</.fg_badge>
                      </td>

                      <td class="py-3 px-4 text-right">
                        <.row_actions id={menu_id} open_id={@open_menu_id} kind="sku" title="Actions">
                          <.menu_item
                            label="Ship"
                            icon="truck"
                            disabled={row.available <= 0}
                            phx-click="open_action"
                            phx-value-kind="ship"
                            phx-value-scope="sku"
                            phx-value-target={row.sku}
                          />
                          <.menu_item
                            label="Sample batch"
                            icon="beaker"
                            disabled={row.on_hand <= 0}
                            phx-click="open_action"
                            phx-value-kind="sample"
                            phx-value-scope="sku"
                            phx-value-target={row.sku}
                          />
                          <.menu_item
                            label="Place hold"
                            icon="shield-alert"
                            disabled={row.available <= 0}
                            phx-click="open_action"
                            phx-value-kind="hold"
                            phx-value-scope="sku"
                            phx-value-target={row.sku}
                          />
                          <.menu_item
                            label="Release hold"
                            icon="check-circle"
                            disabled={row.on_hold <= 0}
                            phx-click="open_action"
                            phx-value-kind="release_hold"
                            phx-value-scope="sku"
                            phx-value-target={row.sku}
                          />
                          <.menu_divider />
                          <.menu_item
                            label="Dispose"
                            icon="trash"
                            tone="danger"
                            disabled={row.on_hand <= 0}
                            phx-click="open_action"
                            phx-value-kind="dispose"
                            phx-value-scope="sku"
                            phx-value-target={row.sku}
                          />
                        </.row_actions>
                      </td>
                    </tr>
                  <% end %>

                  <%= if @sku_rows == [] do %>
                    <tr>
                      <td colspan="7" class="py-6 text-center text-sm text-gray-500">
                        No matching SKUs for the current scope/search.
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <div class="mt-4 text-xs text-gray-500">
              Tip: Use “Actions” for day-to-day ops. The drawer enforces core constraints; “Dispose” requires a reason.
            </div>
          </.fg_card>
          
    <!-- Expiry Risk Panel (lot-level actions) -->
          <.fg_card title="⏰ Expiry Risk Panel" class="mb-8">
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-200">
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Lot ID</th>
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">SKU</th>
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Expiry</th>
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Qty</th>
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Location</th>
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Days</th>
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Status</th>
                    <th class="text-right py-2 px-2 font-semibold text-gray-600">Actions</th>
                  </tr>
                </thead>

                <tbody class="divide-y divide-gray-100">
                  <%= for lot <- @expiring_lots_filtered do %>
                    <% menu_id = "lot:" <> lot.id %>
                    <tr class="hover:bg-gray-50">
                      <td class="py-2 px-2">
                        <.lot_chip
                          lot_id={lot.id}
                          expiry_date={lot.expiry}
                          days_until_expiry={lot.days}
                        />
                      </td>
                      <td class="py-2 px-2 font-medium">
                        <button
                          type="button"
                          class="hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 rounded"
                          phx-click="select_sku"
                          phx-value-sku={lot.sku}
                        >
                          {lot.sku}
                        </button>
                      </td>
                      <td class="py-2 px-2 text-gray-600">{lot.expiry}</td>
                      <td class="py-2 px-2">{lot.qty}u</td>
                      <td class="py-2 px-2 text-gray-600">{lot.location}</td>
                      <td class="py-2 px-2">
                        <.fg_badge variant={expiry_badge_variant(lot.days)}>{lot.days}d</.fg_badge>
                      </td>
                      <td class="py-2 px-2">
                        <.fg_badge variant={if(lot.status == "HOLD", do: "warning", else: "neutral")}>
                          {lot.status}
                        </.fg_badge>
                      </td>

                      <td class="py-2 px-2 text-right">
                        <.row_actions id={menu_id} open_id={@open_menu_id} kind="lot" title="Actions">
                          <.menu_item
                            label="Ship"
                            icon="truck"
                            disabled={
                              lot.qty <= 0 or lot.status == "HOLD" or is_quarantine?(lot.location)
                            }
                            helper={ship_disabled_helper(lot)}
                            phx-click="open_action"
                            phx-value-kind="ship"
                            phx-value-scope="lot"
                            phx-value-target={lot.id}
                          />
                          <.menu_item
                            label="Sample batch"
                            icon="beaker"
                            disabled={lot.qty <= 0}
                            phx-click="open_action"
                            phx-value-kind="sample"
                            phx-value-scope="lot"
                            phx-value-target={lot.id}
                          />
                          <.menu_item
                            label="Place hold"
                            icon="shield-alert"
                            disabled={lot.status == "HOLD"}
                            phx-click="open_action"
                            phx-value-kind="hold"
                            phx-value-scope="lot"
                            phx-value-target={lot.id}
                          />
                          <.menu_item
                            label="Release hold"
                            icon="check-circle"
                            disabled={lot.status != "HOLD"}
                            phx-click="open_action"
                            phx-value-kind="release_hold"
                            phx-value-scope="lot"
                            phx-value-target={lot.id}
                          />
                          <.menu_divider />
                          <.menu_item
                            label="Dispose"
                            icon="trash"
                            tone="danger"
                            disabled={lot.qty <= 0}
                            phx-click="open_action"
                            phx-value-kind="dispose"
                            phx-value-scope="lot"
                            phx-value-target={lot.id}
                          />
                        </.row_actions>
                      </td>
                    </tr>
                  <% end %>

                  <%= if @expiring_lots_filtered == [] do %>
                    <tr>
                      <td colspan="8" class="py-6 text-center text-sm text-gray-500">
                        No matching lots for the current scope/search.
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <div class="mt-4 text-xs text-gray-500">
              Rules: Quarantine lots cannot ship. HOLD lots must be released before shipping.
            </div>
          </.fg_card>
          
    <!-- Location Overview -->
          <.fg_card title="🏷️ Location Overview" class="mb-8">
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-200">
                    <th class="text-left py-2 px-2 font-semibold text-gray-600">Location</th>
                    <th class="text-right py-2 px-2 font-semibold text-gray-600">On-Hand</th>
                    <th class="text-right py-2 px-2 font-semibold text-gray-600">Available</th>
                    <th class="text-right py-2 px-2 font-semibold text-gray-600">Reserved</th>
                    <th class="text-right py-2 px-2 font-semibold text-gray-600">On-Hold</th>
                    <th class="text-right py-2 px-2 font-semibold text-gray-600">Expiring</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <%= for l <- @location_stock do %>
                    <tr class="hover:bg-gray-50">
                      <td class="py-2 px-2 font-medium text-gray-900">{l.location}</td>
                      <td class="py-2 px-2 text-right">{format_int(l.on_hand)}</td>
                      <td class="py-2 px-2 text-right text-green-700">{format_int(l.available)}</td>
                      <td class="py-2 px-2 text-right text-purple-700">{format_int(l.reserved)}</td>
                      <td class="py-2 px-2 text-right text-amber-700">{format_int(l.on_hold)}</td>
                      <td class="py-2 px-2 text-right text-orange-700">{format_int(l.expiring)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </.fg_card>
          
    <!-- Activity Panels -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <.fg_card title="🧾 Recent Activity">
              <ul class="space-y-3">
                <%= for a <- @recent_activity do %>
                  <li class="flex items-start justify-between gap-4">
                    <div>
                      <p class="text-sm text-gray-900 font-medium">{a.action}</p>
                      <p class="text-xs text-gray-500">
                        {a.time} • {a.user}{if a.sku, do: " • " <> a.sku, else: ""}
                      </p>
                    </div>
                  </li>
                <% end %>
              </ul>
            </.fg_card>

            <.fg_card title="🛡️ Suspicious Signals">
              <ul class="space-y-3">
                <%= for s <- @suspicious_activity do %>
                  <li class="flex items-start justify-between gap-4">
                    <div>
                      <p class="text-sm text-gray-900 font-medium">{s.detail}</p>
                      <p class="text-xs text-gray-500">
                        {s.time} • {s.user}{if s.sku, do: " • " <> s.sku, else: ""}
                      </p>
                    </div>
                    <.fg_badge variant={severity_variant(s.severity)}>
                      {String.upcase(s.severity)}
                    </.fg_badge>
                  </li>
                <% end %>
              </ul>
            </.fg_card>
          </div>
          
    <!-- Action Drawer -->
          <%= if @action_open do %>
            <div class="fixed inset-0 z-40">
              <div class="absolute inset-0 bg-black/30" phx-click="close_action"></div>

              <div class="absolute right-0 top-0 h-full w-full sm:w-[520px] bg-white shadow-xl border-l border-gray-200">
                <div class="p-6 border-b border-gray-200 flex items-start justify-between">
                  <div>
                    <h2 class="text-lg font-semibold text-gray-900">{action_title(@action_kind)}</h2>
                    <p class="text-sm text-gray-500 mt-1">
                      Target: <span class="font-semibold text-gray-700">{@action_target}</span>
                      <%= if @action_scope == "lot" do %>
                        •
                        <span class="text-gray-500">
                          {lot_context(@expiring_lots, @action_target)}
                        </span>
                      <% else %>
                        • <span class="text-gray-500">{sku_label(@skus, @action_target)}</span>
                      <% end %>
                    </p>
                  </div>

                  <.fg_button variant="ghost" size="sm" phx-click="close_action">Close</.fg_button>
                </div>

                <div class="p-6 space-y-5 overflow-y-auto h-[calc(100%-148px)]">
                  <%= if @action_error do %>
                    <div class="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-900">
                      <.fg_svg_icon name="alert-circle" class="w-4 h-4 inline mr-2" />
                      {@action_error}
                    </div>
                  <% end %>

                  <%= if @action_warning do %>
                    <div class="bg-orange-50 border border-orange-200 rounded-lg p-3 text-sm text-orange-900">
                      <.fg_svg_icon name="alert-circle" class="w-4 h-4 inline mr-2" />
                      {@action_warning}
                    </div>
                  <% end %>

                  <.form for={%{}} as={:action} phx-change="action_change">
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-900 mb-1">
                          Quantity (units)
                        </label>
                        <input
                          type="number"
                          min="0"
                          name="action[qty]"
                          value={@action_qty}
                          class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                          placeholder={@action_qty_placeholder}
                        />
                        <p class="mt-1 text-xs text-gray-500">{@action_qty_hint}</p>
                      </div>

                      <%= if @action_kind == "ship" do %>
                        <div>
                          <label class="block text-sm font-medium text-gray-900 mb-1">
                            Ship To
                          </label>
                          <select
                            name="action[dest]"
                            class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                          >
                            <%= for opt <- ["Dispatch Chiller", "Purée Fridge", "Purée Freezer", "Returns Quarantine"] do %>
                              <option value={opt} selected={@action_dest == opt}>{opt}</option>
                            <% end %>
                          </select>
                          <p class="mt-1 text-xs text-gray-500">
                            Destination used for the activity log (mock).
                          </p>
                        </div>
                      <% end %>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-900 mb-1">Reason</label>
                      <input
                        type="text"
                        name="action[reason]"
                        value={@action_reason}
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        placeholder={@action_reason_placeholder}
                      />
                      <p class="mt-1 text-xs text-gray-500">{@action_reason_hint}</p>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-900 mb-1">
                        Notes (optional)
                      </label>
                      <textarea
                        name="action[note]"
                        rows="3"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        placeholder="Add context for QA / audit trail..."
                      ><%= @action_note %></textarea>
                    </div>
                  </.form>

                  <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
                    <p class="text-sm font-semibold text-gray-900 mb-2">Preview</p>
                    <div class="text-sm text-gray-700 space-y-2">
                      <div class="flex justify-between">
                        <span>Action:</span>
                        <span class="font-medium text-gray-900">{action_title(@action_kind)}</span>
                      </div>
                      <div class="flex justify-between">
                        <span>Quantity:</span>
                        <span class="font-medium text-gray-900">{@action_preview_qty_label}</span>
                      </div>
                      <%= if @action_preview_effect do %>
                        <div class="pt-2 border-t border-gray-200 text-xs text-gray-600">
                          {@action_preview_effect}
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <div class="p-6 border-t border-gray-200 flex items-center justify-between">
                  <.fg_button variant="secondary" phx-click="close_action">Cancel</.fg_button>
                  <.fg_button
                    variant="primary"
                    phx-click="confirm_action"
                    disabled={!@action_can_confirm}
                  >
                    Confirm
                  </.fg_button>
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
  # “Well-designed” action buttons: Popover menu components
  # =============================================================================

  attr :id, :string, required: true
  attr :open_id, :string, default: nil
  attr :title, :string, default: "Actions"
  attr :kind, :string, default: "row"
  slot :inner_block, required: true

  def row_actions(assigns) do
    assigns = assign(assigns, :open?, assigns.open_id == assigns.id)

    ~H"""
    <div class="relative inline-block text-left">
      <button
        type="button"
        phx-click="toggle_row_menu"
        phx-value-id={@id}
        class={[
          "inline-flex items-center gap-2 rounded-full h-9 px-4 text-sm",
          "bg-gray-100 text-gray-900 hover:bg-gray-200 transition-colors",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
        ]}
        aria-haspopup="menu"
        aria-expanded={@open?}
      >
        <span>{@title}</span>
        <span class="text-gray-500">▾</span>
      </button>

      <%= if @open? do %>
        <div
          class="absolute right-0 z-30 mt-2 w-56 origin-top-right rounded-xl bg-white shadow-lg ring-1 ring-black/5 border border-gray-200"
          phx-click-away="close_row_menu"
        >
          <div class="py-2">
            {render_slot(@inner_block)}
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, default: nil
  # "default" | "danger"
  attr :tone, :string, default: "default"
  attr :disabled, :boolean, default: false
  attr :helper, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value-kind phx-value-scope phx-value-target)

  def menu_item(assigns) do
    base =
      "w-full text-left px-3 py-2 text-sm flex items-start gap-2 transition-colors"

    enabled =
      cond do
        assigns.tone == "danger" -> "text-red-700 hover:bg-red-50"
        true -> "text-gray-700 hover:bg-gray-50"
      end

    disabled = "text-gray-400 cursor-not-allowed"

    assigns =
      assigns
      |> assign(
        :btn_class,
        Enum.join([base, if(assigns.disabled, do: disabled, else: enabled)], " ")
      )

    ~H"""
    <button type="button" class={@btn_class} disabled={@disabled} {@rest}>
      <%= if @icon do %>
        <span class="mt-0.5">
          <.fg_svg_icon name={@icon} class="w-4 h-4" />
        </span>
      <% end %>

      <span class="flex-1">
        <span class="block font-medium">{@label}</span>
        <%= if @helper do %>
          <span class="block text-xs text-gray-500 mt-0.5">{@helper}</span>
        <% end %>
      </span>
    </button>
    """
  end

  def menu_divider(assigns) do
    ~H"""
    <div class="my-2 border-t border-gray-100"></div>
    """
  end

  # =============================================================================
  # Components (chips/cards/badges/buttons/icons)
  # =============================================================================

  attr :sku, :string, required: true
  attr :label, :string, required: true
  attr :selected, :boolean, default: false

  def sku_chip(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="select_sku"
      phx-value-sku={@sku}
      class={[
        "inline-flex items-center rounded-full px-3 py-1 text-sm ring-1 ring-inset transition-colors",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
        if(@selected,
          do: "bg-[#2E7D32] text-white ring-[#2E7D32]",
          else: "bg-white text-gray-700 ring-gray-200 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  def stat_card(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm font-medium text-gray-600">{@title}</p>
          <p class="mt-2 text-2xl font-bold text-gray-900">{@value}</p>
        </div>
        <div class={["rounded-lg p-3", @color]}>
          <.fg_svg_icon name={@icon} class="w-6 h-6" />
        </div>
      </div>
    </div>
    """
  end

  attr :lot_id, :string, required: true
  attr :expiry_date, :string, required: true
  attr :days_until_expiry, :integer, required: true

  def lot_chip(assigns) do
    variant =
      cond do
        assigns.days_until_expiry <= 0 -> "danger"
        assigns.days_until_expiry <= 2 -> "danger"
        assigns.days_until_expiry <= 6 -> "warning"
        true -> "success"
      end

    assigns = assign(assigns, :variant, variant)

    ~H"""
    <div class="inline-flex items-center gap-2">
      <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-1 text-xs font-semibold text-gray-800 ring-1 ring-inset ring-gray-200">
        {@lot_id}
      </span>
      <.fg_badge variant={@variant}>{@expiry_date}</.fg_badge>
    </div>
    """
  end

  attr :title, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def fg_card(assigns) do
    ~H"""
    <div class={["bg-white border border-gray-200 rounded-xl shadow-sm p-6", @class]}>
      <%= if @title do %>
        <div class="mb-5">
          <h3 class="text-base font-semibold text-gray-900">{@title}</h3>
        </div>
      <% end %>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :variant, :string, default: "neutral"
  slot :inner_block, required: true

  def fg_badge(assigns) do
    {bg, text, ring} =
      case assigns.variant do
        "success" -> {"bg-green-50", "text-green-700", "ring-green-200"}
        "warning" -> {"bg-amber-50", "text-amber-700", "ring-amber-200"}
        "danger" -> {"bg-red-50", "text-red-700", "ring-red-200"}
        _ -> {"bg-gray-100", "text-gray-700", "ring-gray-200"}
      end

    assigns = assign(assigns, bg: bg, text: text, ring: ring)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset",
      @bg,
      @text,
      @ring
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :class, :string, default: nil
  attr :disabled, :boolean, default: false

  attr :rest, :global, include: ~w(
      phx-click phx-value-sku phx-value-kind phx-value-scope phx-value-target phx-value-id
      phx-disable-with type
    )

  slot :inner_block, required: true

  def fg_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap transition-colors " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
        "disabled:opacity-50 disabled:cursor-not-allowed"

    size =
      case assigns.size do
        "sm" -> "h-9 px-4 text-sm rounded-full"
        "lg" -> "h-11 px-5 text-sm rounded-full"
        _ -> "h-9 px-4 text-sm rounded-full"
      end

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 hover:bg-gray-200"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm h-auto"
        _ -> "bg-[#2E7D32] text-white hover:brightness-95"
      end

    class =
      if assigns.variant == "ghost" do
        Enum.join([base, variant, assigns.class || ""], " ")
      else
        Enum.join([base, size, variant, assigns.class || ""], " ")
      end

    assigns = assign(assigns, :btn_class, class)

    ~H"""
    <button class={@btn_class} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  # =============================================================================
  # Business logic: recompute, action preview, and mock state mutations
  # =============================================================================

  defp recompute(socket) do
    selected = socket.assigns.selected_sku
    q = socket.assigns.q

    expiring_lots =
      socket.assigns.expiring_lots
      |> Enum.map(&normalize_lot/1)
      |> Enum.sort_by(& &1.days)

    # Keep base lots normalized so drawer validations/warnings stay accurate
    socket = assign(socket, expiring_lots: expiring_lots)

    selection =
      case selected do
        "ALL" -> socket.assigns.sku_stock
        sku -> Enum.filter(socket.assigns.sku_stock, &(&1.sku == sku))
      end

    kpi =
      Enum.reduce(
        selection,
        %{on_hand: 0, available: 0, reserved: 0, on_hold: 0, expiring_7d: 0, shrinkage_mtd: 0},
        fn r, acc ->
          %{
            on_hand: acc.on_hand + r.on_hand,
            available: acc.available + r.available,
            reserved: acc.reserved + r.reserved,
            on_hold: acc.on_hold + r.on_hold,
            expiring_7d: acc.expiring_7d + r.expiring_7d,
            shrinkage_mtd: acc.shrinkage_mtd + r.shrinkage_mtd
          }
        end
      )

    sku_rows_all =
      socket.assigns.sku_stock
      |> Enum.map(fn r ->
        label = sku_label(socket.assigns.skus, r.sku)
        {risk_label, risk_badge} = sku_risk(r.expiring_7d, r.on_hold, r.shrinkage_mtd, r.on_hand)

        Map.merge(r, %{
          label: label,
          risk_label: risk_label,
          risk_badge: risk_badge,
          search_text: "#{r.sku} #{label}"
        })
      end)
      |> Enum.sort_by(fn r ->
        {risk_rank(r.risk_label), -r.expiring_7d, -r.on_hold, -r.on_hand, r.sku}
      end)

    sku_rows_filtered =
      Enum.filter(sku_rows_all, fn r ->
        (selected == "ALL" or r.sku == selected) and matches_query?(q, r.search_text)
      end)

    expiring_lots_filtered =
      expiring_lots
      |> Enum.filter(fn lot ->
        sku_ok = selected == "ALL" or lot.sku == selected
        text = "#{lot.id} #{lot.sku} #{lot.location} #{lot.expiry} #{lot.status}"
        sku_ok and matches_query?(q, text)
      end)

    socket
    |> assign(
      kpi: kpi,
      sku_rows: sku_rows_filtered,
      expiring_lots_filtered: expiring_lots_filtered
    )
    |> recompute_action_preview()
  end

  defp recompute_action_preview(socket) do
    if socket.assigns.action_open do
      raw_qty = parse_qty_input(socket.assigns.action_qty)

      eff_qty =
        effective_qty(
          socket.assigns.action_kind,
          socket.assigns.action_scope,
          socket.assigns.action_target,
          raw_qty,
          socket
        )

      {hint, placeholder} =
        qty_hint(
          socket.assigns.action_kind,
          socket.assigns.action_scope,
          socket.assigns.action_target,
          socket
        )

      {reason_hint, reason_placeholder} = reason_hint(socket.assigns.action_kind)

      warning =
        action_warning(
          socket.assigns.action_kind,
          socket.assigns.action_scope,
          socket.assigns.action_target,
          eff_qty,
          socket
        )

      effect =
        action_effect_preview(
          socket.assigns.action_kind,
          socket.assigns.action_scope,
          socket.assigns.action_target,
          eff_qty
        )

      qty_label =
        case {raw_qty, socket.assigns.action_kind} do
          {:blank, kind} when kind in ["hold", "release_hold"] ->
            "All (#{eff_qty} u)"

          {:blank, _} ->
            "#{eff_qty} u"

          {:invalid, _} ->
            "0 u"

          {n, _} when is_integer(n) ->
            "#{n} u"
        end

      validation =
        validate_action(
          socket.assigns.action_kind,
          socket.assigns.action_scope,
          socket.assigns.action_target,
          eff_qty,
          socket
        )

      {can_confirm, action_error} =
        case validation do
          :ok -> {true, nil}
          {:error, msg} -> {false, msg}
        end

      assign(socket,
        action_preview_qty: eff_qty,
        action_preview_qty_label: qty_label,
        action_qty_hint: hint,
        action_qty_placeholder: placeholder,
        action_reason_hint: reason_hint,
        action_reason_placeholder: reason_placeholder,
        action_warning: warning,
        action_preview_effect: effect,
        action_error: action_error,
        action_can_confirm: can_confirm
      )
    else
      assign(socket,
        action_preview_qty: 0,
        action_preview_qty_label: "0 u",
        action_qty_hint: "",
        action_qty_placeholder: "",
        action_reason_hint: "",
        action_reason_placeholder: "",
        action_warning: nil,
        action_preview_effect: nil,
        action_error: nil,
        action_can_confirm: false
      )
    end
  end

  # -------------------------
  # Apply action (mock, but practical)
  # -------------------------

  defp apply_action(socket) do
    kind = socket.assigns.action_kind
    scope = socket.assigns.action_scope
    target = socket.assigns.action_target

    raw_qty = parse_qty_input(socket.assigns.action_qty)
    qty = effective_qty(kind, scope, target, raw_qty, socket)

    case validate_action(kind, scope, target, qty, socket) do
      :ok ->
        case {scope, kind} do
          {"lot", _} -> apply_lot_action(socket, kind, target, qty)
          {"sku", _} -> apply_sku_action(socket, kind, target, qty)
          _ -> {:error, "Invalid action scope.", socket}
        end

      {:error, msg} ->
        {:error, msg, socket}
    end
  end

  defp apply_lot_action(socket, kind, lot_id, qty) do
    case Enum.find(socket.assigns.expiring_lots, &(&1.id == lot_id)) do
      nil ->
        {:error, "Lot not found.", socket}

      lot ->
        cond do
          kind == "ship" and (lot.status == "HOLD" or is_quarantine?(lot.location)) ->
            {:error, "Cannot ship: lot is on HOLD or in Quarantine.", socket}

          kind in ["ship", "dispose", "sample"] and qty > lot.qty ->
            {:error, "Quantity exceeds lot quantity.", socket}

          kind == "dispose" and String.trim(socket.assigns.action_reason || "") == "" ->
            {:error, "Dispose requires a reason (waste category).", socket}

          true ->
            sku = lot.sku

            case kind do
              "ship" ->
                socket =
                  socket
                  |> consume_from_lot(lot_id, qty, fn sku_row ->
                    sku_row
                    |> dec(:available, qty)
                    |> dec(:on_hand, qty)
                    |> dec(:expiring_7d, min(qty, sku_row.expiring_7d))
                  end)

                {:ok, socket}

              "sample" ->
                socket =
                  socket
                  |> consume_from_lot(lot_id, qty, fn sku_row ->
                    sku_row
                    |> dec(:on_hand, qty)
                    |> dec(:expiring_7d, min(qty, sku_row.expiring_7d))
                  end)

                {:ok, socket}

              "dispose" ->
                socket =
                  socket
                  |> consume_from_lot(lot_id, qty, fn sku_row ->
                    sku_row
                    |> dec(:on_hand, qty)
                    |> dec(:available, min(qty, sku_row.available))
                    |> dec(:expiring_7d, min(qty, sku_row.expiring_7d))
                    |> inc(:shrinkage_mtd, qty)
                  end)

                {:ok, socket}

              "hold" ->
                hold_qty = min(qty, lot.qty)

                socket =
                  socket
                  |> update_lot(lot_id, fn l -> %{l | status: "HOLD"} end)
                  |> update_sku(sku, fn sku_row ->
                    move_qty = min(hold_qty, sku_row.available)
                    sku_row |> dec(:available, move_qty) |> inc(:on_hold, move_qty)
                  end)

                {:ok, socket}

              "release_hold" ->
                release_qty = min(qty, lot.qty)

                socket =
                  socket
                  |> update_lot(lot_id, fn l -> %{l | status: "OK"} end)
                  |> update_sku(sku, fn sku_row ->
                    move_qty = min(release_qty, sku_row.on_hold)
                    sku_row |> dec(:on_hold, move_qty) |> inc(:available, move_qty)
                  end)

                {:ok, socket}

              _ ->
                {:error, "Unsupported action.", socket}
            end
        end
    end
  end

  defp apply_sku_action(socket, kind, sku, qty) do
    row = Enum.find(socket.assigns.sku_stock, &(&1.sku == sku))

    if is_nil(row) do
      {:error, "SKU not found.", socket}
    else
      cond do
        kind == "ship" and qty > row.available ->
          {:error, "Cannot ship: quantity exceeds Available.", socket}

        kind == "hold" and qty > row.available ->
          {:error, "Cannot hold: quantity exceeds Available.", socket}

        kind == "release_hold" and qty > row.on_hold ->
          {:error, "Cannot release: quantity exceeds On-Hold.", socket}

        kind == "sample" and qty > row.on_hand ->
          {:error, "Cannot sample: quantity exceeds On-Hand.", socket}

        kind == "dispose" and qty > row.on_hand ->
          {:error, "Cannot dispose: quantity exceeds On-Hand.", socket}

        kind == "dispose" and String.trim(socket.assigns.action_reason || "") == "" ->
          {:error, "Dispose requires a reason (waste category).", socket}

        true ->
          case kind do
            "ship" ->
              {:ok,
               update_sku(socket, sku, fn r ->
                 r
                 |> dec(:available, qty)
                 |> dec(:on_hand, qty)
                 |> dec(:expiring_7d, min(qty, r.expiring_7d))
               end)}

            "hold" ->
              {:ok,
               update_sku(socket, sku, fn r -> r |> dec(:available, qty) |> inc(:on_hold, qty) end)}

            "release_hold" ->
              {:ok,
               update_sku(socket, sku, fn r -> r |> dec(:on_hold, qty) |> inc(:available, qty) end)}

            "sample" ->
              {:ok,
               update_sku(socket, sku, fn r ->
                 r |> dec(:on_hand, qty) |> dec(:expiring_7d, min(qty, r.expiring_7d))
               end)}

            "dispose" ->
              {:ok,
               update_sku(socket, sku, fn r ->
                 r
                 |> dec(:on_hand, qty)
                 |> dec(:available, min(qty, r.available))
                 |> dec(:expiring_7d, min(qty, r.expiring_7d))
                 |> inc(:shrinkage_mtd, qty)
               end)}

            _ ->
              {:error, "Unsupported action.", socket}
          end
      end
    end
  end

  defp consume_from_lot(socket, lot_id, qty, sku_fun) do
    lot = Enum.find(socket.assigns.expiring_lots, &(&1.id == lot_id))
    sku = lot.sku

    socket
    |> update_lot(lot_id, fn l -> %{l | qty: max(l.qty - qty, 0)} end)
    |> maybe_remove_lot(lot_id)
    |> update_sku(sku, sku_fun)
  end

  defp maybe_remove_lot(socket, lot_id) do
    lot = Enum.find(socket.assigns.expiring_lots, &(&1.id == lot_id))

    if lot && lot.qty <= 0 do
      assign(socket, expiring_lots: Enum.reject(socket.assigns.expiring_lots, &(&1.id == lot_id)))
    else
      socket
    end
  end

  # =============================================================================
  # Helper logic and validations
  # =============================================================================

  defp clear_action(socket) do
    assign(socket,
      action_open: false,
      action_kind: nil,
      action_scope: nil,
      action_target: nil,
      action_qty: "",
      action_dest: "Dispatch Chiller",
      action_reason: "",
      action_note: "",
      action_warning: nil,
      action_preview_effect: nil,
      action_error: nil,
      action_can_confirm: false,
      action_preview_qty: 0,
      action_preview_qty_label: "0 u"
    )
  end

  defp action_title(kind) do
    case kind do
      "ship" -> "Ship Finished Goods"
      "dispose" -> "Dispose Finished Goods"
      "sample" -> "Sample Batch"
      "hold" -> "Place Hold"
      "release_hold" -> "Release Hold"
      _ -> "Action"
    end
  end

  defp default_action_fields(kind) do
    case kind do
      "sample" -> {"1", "QC sample"}
      "dispose" -> {"", ""}
      "ship" -> {"", "Customer shipment"}
      "hold" -> {"", "QC hold"}
      "release_hold" -> {"", "QC release"}
      _ -> {"", ""}
    end
  end

  defp reason_hint(kind) do
    case kind do
      "dispose" ->
        {"Required for audit (e.g., damage, expiry, contamination).",
         "e.g., Expired / Damaged / Contamination"}

      "hold" ->
        {"Optional but recommended (e.g., QC review, label issue).", "e.g., QC review"}

      "release_hold" ->
        {"Optional (e.g., QC passed).", "e.g., QC passed"}

      "sample" ->
        {"Optional (e.g., micro, pH, sensory).", "e.g., Micro + pH"}

      "ship" ->
        {"Optional (e.g., order/route).", "e.g., ORD-1234 / Route A"}

      _ ->
        {"", ""}
    end
  end

  defp qty_hint(kind, "lot", lot_id, socket) do
    lot = Enum.find(socket.assigns.expiring_lots, &(&1.id == lot_id))

    if lot do
      case kind do
        "ship" ->
          {"Max #{lot.qty} (lot qty).", "#{lot.qty}"}

        "dispose" ->
          {"Max #{lot.qty} (lot qty).", "#{lot.qty}"}

        "sample" ->
          {"Typical: 1–3 units. Max #{lot.qty}.", "1"}

        "hold" ->
          {"Leave empty to hold full lot; or specify partial hold.", "#{lot.qty}"}

        "release_hold" ->
          {"Leave empty to release full lot; or specify partial release.", "#{lot.qty}"}

        _ ->
          {"", ""}
      end
    else
      {"", ""}
    end
  end

  defp qty_hint(kind, "sku", sku, socket) do
    row = Enum.find(socket.assigns.sku_stock, &(&1.sku == sku))

    if row do
      case kind do
        "ship" -> {"Max #{row.available} (available).", "#{row.available}"}
        "hold" -> {"Max #{row.available} (available).", "#{row.available}"}
        "release_hold" -> {"Max #{row.on_hold} (on-hold).", "#{row.on_hold}"}
        "sample" -> {"Max #{row.on_hand} (on-hand). Typical: 1–3.", "1"}
        "dispose" -> {"Max #{row.on_hand} (on-hand).", "#{row.on_hand}"}
        _ -> {"", ""}
      end
    else
      {"", ""}
    end
  end

  defp action_warning(kind, "lot", lot_id, qty, socket) do
    lot = Enum.find(socket.assigns.expiring_lots, &(&1.id == lot_id))

    cond do
      is_nil(lot) ->
        nil

      kind == "ship" and is_quarantine?(lot.location) ->
        "This lot is in Quarantine. Shipping is blocked."

      kind == "ship" and lot.status == "HOLD" ->
        "This lot is on HOLD. Release the hold before shipping."

      kind == "sample" and qty > 3 ->
        "Sampling more than 3 units is unusual. Confirm you intend a larger sample."

      kind == "dispose" and lot.days <= 2 ->
        "Expiry is imminent. Ensure disposal follows your waste SOP and documentation."

      true ->
        nil
    end
  end

  defp action_warning(kind, "sku", sku, qty, socket) do
    row = Enum.find(socket.assigns.sku_stock, &(&1.sku == sku))

    cond do
      is_nil(row) ->
        nil

      kind == "sample" and qty > 3 ->
        "Sampling more than 3 units is unusual. Confirm you intend a larger sample."

      true ->
        nil
    end
  end

  defp action_effect_preview(kind, scope, _target, qty) do
    case {kind, scope} do
      {"ship", _} ->
        "Will reduce Available and On-Hand by #{qty}. Expiring may reduce as well."

      {"hold", _} ->
        "Will move units from Available to On-Hold (and may mark the lot HOLD)."

      {"release_hold", _} ->
        "Will move units from On-Hold back to Available (and may mark the lot OK)."

      {"sample", _} ->
        "Will reduce On-Hand by #{qty}. Typical usage: micro/pH/sensory QA."

      {"dispose", _} ->
        "Will reduce On-Hand by #{qty}. Increments shrinkage and reduces expiring if applicable."

      _ ->
        nil
    end
  end

  defp ship_disabled_helper(lot) do
    cond do
      is_quarantine?(lot.location) -> "Quarantine"
      lot.status == "HOLD" -> "On hold"
      lot.qty <= 0 -> "No qty"
      true -> nil
    end
  end

  defp lot_context(expiring_lots, lot_id) do
    case Enum.find(expiring_lots, &(&1.id == lot_id)) do
      nil -> "—"
      lot -> "#{lot.sku} • #{lot.location} • #{lot.qty}u • #{lot.status}"
    end
  end

  defp sku_label(skus, code) do
    case Enum.find(skus, &(&1.code == code)) do
      nil -> "—"
      sku -> "#{sku.name} • #{sku.container} • #{sku.volume_ml}ml"
    end
  end

  defp detect_sku(text, skus) when is_binary(text) do
    codes = Enum.map(skus, & &1.code)
    Enum.find(codes, fn code -> String.contains?(text, code) end)
  end

  defp detect_sku(_text, _skus), do: nil

  defp sku_in_catalog?(sku, skus), do: Enum.any?(skus, &(&1.code == sku))

  defp sku_risk(expiring_7d, on_hold, shrinkage_mtd, on_hand) do
    on_hand = max(on_hand, 0)
    expiry_share = if on_hand > 0, do: expiring_7d / on_hand, else: 0.0
    hold_share = if on_hand > 0, do: on_hold / on_hand, else: 0.0

    score =
      100.0 * expiry_share * 0.70 + 100.0 * hold_share * 0.20 +
        min(shrinkage_mtd * 1.0, 20.0) * 0.50

    cond do
      on_hand == 0 -> {"No Stock", "neutral"}
      score >= 20.0 -> {"Critical", "danger"}
      score >= 8.0 -> {"Elevated", "warning"}
      true -> {"Normal", "success"}
    end
  end

  defp risk_rank(label) do
    case label do
      "Critical" -> 0
      "Elevated" -> 1
      "Normal" -> 2
      "No Stock" -> 3
      _ -> 9
    end
  end

  defp expiry_badge_variant(days) when is_integer(days) do
    cond do
      days <= 0 -> "danger"
      days <= 2 -> "danger"
      days <= 6 -> "warning"
      true -> "success"
    end
  end

  defp is_quarantine?(location) when is_binary(location),
    do: String.contains?(String.downcase(location), "quarantine")

  defp update_lot(socket, lot_id, fun) do
    assign(socket,
      expiring_lots:
        Enum.map(socket.assigns.expiring_lots, fn l ->
          if l.id == lot_id, do: fun.(l), else: l
        end)
    )
  end

  defp update_sku(socket, sku, fun) do
    assign(socket,
      sku_stock:
        Enum.map(socket.assigns.sku_stock, fn r ->
          if r.sku == sku, do: fun.(r), else: r
        end)
    )
  end

  defp inc(map, key, n), do: Map.update!(map, key, &(&1 + n))
  defp dec(map, key, n), do: Map.update!(map, key, &max(&1 - n, 0))

  defp format_int(i) when is_integer(i) do
    i
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  # =============================================================================
  # Search helpers
  # =============================================================================

  defp matches_query?(nil, _text), do: true

  defp matches_query?(q, text) when is_binary(q) and is_binary(text) do
    q = String.trim(String.downcase(q))

    if q == "" do
      true
    else
      String.contains?(String.downcase(text), q)
    end
  end

  # =============================================================================
  # Lot normalization (days from expiry)
  # =============================================================================

  defp parse_date!(iso) when is_binary(iso) do
    case Date.from_iso8601(iso) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
  end

  defp days_until(expiry_iso) do
    expiry = parse_date!(expiry_iso)
    Date.diff(expiry, Date.utc_today())
  end

  defp normalize_lot(lot) do
    days = days_until(lot.expiry)

    lot
    |> Map.put(:days, days)
    |> Map.update(:status, "OK", & &1)
  end

  # =============================================================================
  # Quantity parsing + “blank means All” semantics
  # =============================================================================

  defp parse_qty_input(nil), do: :blank
  defp parse_qty_input(v) when is_integer(v), do: max(v, 0)

  defp parse_qty_input(v) when is_binary(v) do
    v = String.trim(v)

    cond do
      v == "" ->
        :blank

      true ->
        case Integer.parse(v) do
          {i, _} -> max(i, 0)
          :error -> :invalid
        end
    end
  end

  defp effective_qty(kind, "sku", sku, :blank, socket) when kind in ["hold", "release_hold"] do
    row = Enum.find(socket.assigns.sku_stock, &(&1.sku == sku))

    case {kind, row} do
      {"hold", %{available: a}} -> a
      {"release_hold", %{on_hold: h}} -> h
      _ -> 0
    end
  end

  defp effective_qty(kind, "lot", lot_id, :blank, socket) when kind in ["hold", "release_hold"] do
    lot = Enum.find(socket.assigns.expiring_lots, &(&1.id == lot_id))
    if lot, do: lot.qty, else: 0
  end

  defp effective_qty(_kind, _scope, _target, :blank, _socket), do: 0
  defp effective_qty(_kind, _scope, _target, :invalid, _socket), do: 0
  defp effective_qty(_kind, _scope, _target, n, _socket) when is_integer(n), do: n

  defp validate_action(kind, scope, target, eff_qty, socket) do
    cond do
      kind in ["ship", "sample", "dispose"] and eff_qty <= 0 ->
        {:error, "Quantity must be greater than 0."}

      kind == "dispose" and String.trim(socket.assigns.action_reason || "") == "" ->
        {:error, "Dispose requires a reason (waste category)."}

      scope == "sku" ->
        row = Enum.find(socket.assigns.sku_stock, &(&1.sku == target))

        cond do
          is_nil(row) ->
            {:error, "SKU not found."}

          kind == "ship" and eff_qty > row.available ->
            {:error, "Cannot ship: exceeds Available."}

          kind == "hold" and eff_qty > row.available ->
            {:error, "Cannot hold: exceeds Available."}

          kind == "release_hold" and eff_qty > row.on_hold ->
            {:error, "Cannot release: exceeds On-Hold."}

          kind == "sample" and eff_qty > row.on_hand ->
            {:error, "Cannot sample: exceeds On-Hand."}

          kind == "dispose" and eff_qty > row.on_hand ->
            {:error, "Cannot dispose: exceeds On-Hand."}

          true ->
            :ok
        end

      scope == "lot" ->
        lot = Enum.find(socket.assigns.expiring_lots, &(&1.id == target))

        cond do
          is_nil(lot) ->
            {:error, "Lot not found."}

          kind == "ship" and (lot.status == "HOLD" or is_quarantine?(lot.location)) ->
            {:error, "Cannot ship: lot is on HOLD or in Quarantine."}

          kind in ["ship", "dispose", "sample"] and eff_qty > lot.qty ->
            {:error, "Quantity exceeds lot quantity."}

          true ->
            :ok
        end

      true ->
        {:error, "Invalid action scope."}
    end
  end

  defp severity_variant(sev) do
    case sev do
      "high" -> "danger"
      "medium" -> "warning"
      _ -> "neutral"
    end
  end
end
