defmodule AvoflowWeb.PickPackShipLive do
  use AvoflowWeb, :live_view

  @steps ["pick", "pack", "ship"]

  # ----------------------------
  # Mount / Params
  # ----------------------------

  @impl true
  def mount(_params, _session, socket) do
    orders = mock_orders()
    inventory_by_sku_original = mock_inventory()

    socket =
      socket
      |> assign(:q, "")
      |> assign(:unread_count, 3)
      |> assign(:user_label, "Warehouse Ops")
      |> assign(:steps, @steps)
      |> assign(:orders, orders)
      |> assign(:inventory_by_sku_original, inventory_by_sku_original)
      # mutable copy used for demo consumption as scans happen
      |> assign(:inventory_by_sku, deep_copy_inventory(inventory_by_sku_original))
      |> assign(:selected_order, nil)
      |> assign(:step, "pick")
      |> assign(:active_sku, nil)
      |> assign(:active_lot_id, nil)
      |> assign(:scan_open, false)
      |> assign(:scan_code, "")
      |> assign(:last_scan, nil)
      |> assign(:picks_by_sku, %{})
      |> assign(:lot_allocations_by_sku, %{})
      |> assign(:pack_form, %{"box_size" => "Medium", "ice_packs" => "2", "insulation" => "true"})
      |> assign(:cold_chain_timer_minutes, 12)
      |> assign(:ship_form, %{
        "carrier" => "DHL Express",
        "tracking_number" => "",
        "shipment_date" => Date.utc_today() |> Date.to_iso8601(),
        "packed_by" => "J.Doe (auto)",
        "verified_by" => ""
      })

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply,
         socket
         |> clear_workflow()
         |> assign(:selected_order, nil)}

      :show ->
        order_id = params["order_id"]

        case Enum.find(socket.assigns.orders, &(&1.id == order_id)) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Order not found: #{order_id}")
             |> push_navigate(to: ~p"/finished-goods/fulfill")}

          order ->
            {:noreply, load_order(socket, order)}
        end
    end
  end

  # ----------------------------
  # Render
  # ----------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <main class="">
        <div class="">
          <%= if info = Phoenix.Flash.get(@flash, :info) do %>
            <div class="mb-5 rounded-xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-900">
              {info}
            </div>
          <% end %>

          <%= if error = Phoenix.Flash.get(@flash, :error) do %>
            <div class="mb-5 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900">
              {error}
            </div>
          <% end %>
          
    <!-- Header -->
          <div class="mb-6">
            <.link
              navigate={~p"/finished-goods"}
              class="flex items-center text-sm text-gray-500 hover:text-gray-900 mb-3 transition-colors"
            >
              <.fg_svg_icon name="arrow-left" class="w-4 h-4 mr-1" /> Back to Finished Goods
            </.link>

            <div class="flex items-center space-x-3 mb-2">
              <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-blue-700 rounded-lg flex items-center justify-center">
                <.pps_icon name="truck" class="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 class="text-2xl font-bold text-gray-900">Pick / Pack / Ship</h1>
                <p class="text-gray-500 text-sm">
                  Fulfill orders with FEFO (First-Expire, First-Out) enforcement and per-SKU availability visibility
                </p>
              </div>
            </div>
          </div>

          <%= if is_nil(@selected_order) do %>
            <.pps_card title="Active Orders Ready to Pick">
              <div class="space-y-3">
                <%= for order <- @orders do %>
                  <div class="p-4 border-2 border-gray-200 rounded-lg hover:border-blue-400 hover:shadow-md transition-all">
                    <div class="flex items-center justify-between mb-2 gap-3">
                      <div class="flex flex-wrap items-center gap-2">
                        <h3 class="font-semibold text-gray-900">{order.id}</h3>

                        <.pps_badge variant={
                          if(order.priority == "urgent", do: "danger", else: "neutral")
                        }>
                          {if order.priority == "urgent", do: "🔴 Urgent", else: "Standard"}
                        </.pps_badge>

                        <.pps_badge variant={
                          if(order.status == "ready", do: "success", else: "warning")
                        }>
                          {order.status}
                        </.pps_badge>
                      </div>

                      <.pps_link_button
                        navigate={~p"/finished-goods/fulfill/#{order.id}"}
                        variant="primary"
                        size="sm"
                      >
                        Pick Order
                      </.pps_link_button>
                    </div>

                    <div class="flex flex-wrap gap-x-6 gap-y-2 items-center text-sm text-gray-600">
                      <span class="flex items-center space-x-1">
                        <.pps_icon name="user" class="w-4 h-4 text-gray-500" />
                        <span>{order.customer}</span>
                      </span>

                      <span class="flex items-center space-x-1">
                        <.pps_icon name="package" class="w-4 h-4 text-gray-500" />
                        <span>{length(order.lines)} SKUs</span>
                      </span>

                      <span class="flex items-center space-x-1">
                        <.pps_icon name="clock" class="w-4 h-4 text-gray-500" />
                        <span>Due: {order.due_date}</span>
                      </span>
                    </div>

                    <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-2">
                      <%= for line <- order.lines do %>
                        <div class="rounded-lg bg-gray-50 border border-gray-200 px-3 py-2 text-xs text-gray-700">
                          <div class="flex items-center justify-between gap-2">
                            <span class="font-semibold text-gray-900">{line.sku_code}</span>
                            <span class="text-gray-600">{line.ordered_qty} {line.uom}</span>
                          </div>
                          <div class="mt-1 text-gray-600">
                            {line.sku_name}
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <div class="mt-4 text-xs text-gray-500">
                      Demo: “Pick Order” opens the workflow route (so refresh/back/links behave like production).
                    </div>
                  </div>
                <% end %>
              </div>
            </.pps_card>
          <% else %>
            <div class="space-y-6">
              <!-- Order Header -->
              <.pps_card>
                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                  <div>
                    <h2 class="text-lg font-bold text-gray-900">{@selected_order.id}</h2>
                    <p class="text-sm text-gray-600">
                      Customer: {@selected_order.customer} • Due: {@selected_order.due_date} • Priority:
                      <span class="font-semibold text-gray-900">{@selected_order.priority}</span>
                    </p>
                  </div>

                  <div class="flex items-center gap-2">
                    <.pps_button variant="secondary" phx-click="cancel_order">
                      Cancel Order
                    </.pps_button>
                  </div>
                </div>
              </.pps_card>
              
    <!-- Progress Steps -->
              <div class="flex items-center justify-center space-x-2 sm:space-x-4">
                <%= for {s, idx} <- Enum.with_index(@steps) do %>
                  <div class="flex items-center space-x-2">
                    <div class={[
                      "w-10 h-10 rounded-full flex items-center justify-center font-semibold",
                      step_class(@step, s, idx)
                    ]}>
                      <%= if step_completed?(@step, s) do %>
                        ✓
                      <% else %>
                        {idx + 1}
                      <% end %>
                    </div>

                    <span class="text-sm font-medium text-gray-700 capitalize">{s}</span>
                  </div>

                  <%= if idx < 2 do %>
                    <div class="w-10 sm:w-16 h-0.5 bg-gray-300" />
                  <% end %>
                <% end %>
              </div>
              
    <!-- Pick Step -->
              <%= if @step == "pick" do %>
                <div class="space-y-6">
                  <!-- LOGICAL ORDER:
                       1) Order Lines & Availability
                       2) FEFO Guidance
                       3) Scan to Pick (opens scanner modal) -->
                  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <!-- 1) Order Lines & Availability -->
                    <.pps_card title="Order Lines & Availability (by SKU)">
                      <div class="space-y-3">
                        <%= for line <- @selected_order.lines do %>
                          <% inv_remaining = Map.get(@inventory_by_sku, line.sku_code, %{lots: []}) %>
                          <% inv_original =
                            Map.get(@inventory_by_sku_original, line.sku_code, inv_remaining) %>
                          <% picked = Map.get(@picks_by_sku, line.sku_code, 0) %>

                          <% on_hand_total = inv_total_available(inv_original) %>
                          <% remaining_on_hand = inv_total_available(inv_remaining) %>

                          <% target = line_target_qty(line, inv_original) %>
                          <% remaining_to_target = max(target - picked, 0) %>
                          <% shortage = max(line.ordered_qty - on_hand_total, 0) %>

                          <div
                            class={[
                              "p-4 border-2 rounded-lg transition-all cursor-pointer",
                              if(@active_sku == line.sku_code,
                                do: "border-blue-400 shadow-sm",
                                else: "border-gray-200 hover:border-blue-400 hover:shadow-md"
                              )
                            ]}
                            phx-click="select_line"
                            phx-value-sku={line.sku_code}
                            role="button"
                            tabindex="0"
                          >
                            <div class="flex items-start justify-between gap-3">
                              <div class="min-w-0">
                                <div class="flex flex-wrap items-center gap-2">
                                  <h3 class="font-semibold text-gray-900">{line.sku_code}</h3>
                                  <.pps_badge variant="neutral">{line.temp_zone}</.pps_badge>

                                  <%= if shortage > 0 do %>
                                    <.pps_badge variant="danger">Short by {shortage}</.pps_badge>
                                  <% else %>
                                    <.pps_badge variant="success">On hand OK</.pps_badge>
                                  <% end %>
                                </div>

                                <p class="mt-1 text-sm text-gray-600">
                                  <span class="font-medium text-gray-900">{line.sku_name}</span>
                                  • Ordered: {line.ordered_qty} {line.uom} • Target:
                                  <span class="font-semibold text-gray-900">{target}</span>
                                  • Picked: <span class="font-semibold text-gray-900">{picked}</span>
                                  • Remaining:
                                  <span class="font-semibold text-gray-900">
                                    {remaining_to_target}
                                  </span>
                                </p>

                                <div class="mt-2 flex flex-wrap gap-3 text-xs text-gray-600">
                                  <span class="flex items-center gap-1">
                                    <span class="font-semibold text-gray-900">On hand:</span>
                                    {on_hand_total} units
                                  </span>
                                  <span class="flex items-center gap-1">
                                    <span class="font-semibold text-gray-900">Remaining:</span>
                                    {remaining_on_hand} units
                                  </span>
                                  <span class="flex items-center gap-1">
                                    <span class="font-semibold text-gray-900">FEFO lot:</span>
                                    {fefo_lot_label(inv_remaining)}
                                  </span>
                                </div>
                              </div>

                              <div class="shrink-0 w-44">
                                <div class="flex items-center justify-between text-xs mb-1">
                                  <span class="text-gray-700">Progress</span>
                                  <span class="font-semibold text-gray-900">
                                    {pct(picked, target)}%
                                  </span>
                                </div>

                                <.pps_progress_bar value={picked} max={target} />

                                <div class="mt-3 text-xs text-gray-600">
                                  Tip: Select SKU → review FEFO → click “Scan to Pick”.
                                </div>
                              </div>
                            </div>

                            <div class="mt-3 rounded-lg bg-gray-50 border border-gray-200 px-3 py-2">
                              <div class="flex items-center justify-between gap-2">
                                <p class="text-xs font-semibold text-gray-900">
                                  Lot availability (earliest expiry first)
                                </p>
                                <p class="text-xs text-gray-600">
                                  Select lot, then scan to consume
                                </p>
                              </div>

                              <div class="mt-2 space-y-1">
                                <%= for lot <- Enum.sort_by(inv_remaining.lots, &parse_date_days(&1.expiry_date)) do %>
                                  <div class="flex flex-wrap items-center justify-between gap-2 text-xs">
                                    <div class="flex items-center gap-2">
                                      <span class="font-semibold text-gray-900">{lot.lot_id}</span>
                                      <span class="text-gray-600">Exp: {lot.expiry_date}</span>
                                      <span class="text-gray-600">
                                        • {lot.location}, Bin {lot.bin}
                                      </span>
                                    </div>

                                    <div class="flex items-center gap-2">
                                      <span class="text-gray-600">Avail:</span>
                                      <span class="font-semibold text-gray-900">
                                        {lot.available_units}
                                      </span>
                                      <%= if lot.available_units == 0 do %>
                                        <.pps_badge variant="warning">Depleted</.pps_badge>
                                      <% end %>
                                    </div>
                                  </div>
                                <% end %>

                                <%= if inv_remaining.lots == [] do %>
                                  <div class="text-xs text-gray-600">No lot data for this SKU.</div>
                                <% end %>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </.pps_card>
                    
    <!-- 2) FEFO Guidance then 3) Scan -->
                    <div class="space-y-6">
                      <.pps_card title="FEFO Pick Guidance (selected SKU)">
                        <%= if is_nil(@active_sku) do %>
                          <p class="text-sm text-gray-600">
                            Select a line item to see FEFO guidance.
                          </p>
                        <% else %>
                          <% inv_remaining = Map.get(@inventory_by_sku, @active_sku, %{lots: []}) %>
                          <% inv_original =
                            Map.get(@inventory_by_sku_original, @active_sku, inv_remaining) %>
                          <% line = find_line(@selected_order, @active_sku) %>
                          <% picked = Map.get(@picks_by_sku, @active_sku, 0) %>
                          <% target = line_target_qty(line, inv_original) %>
                          <% remaining_to_target = max(target - picked, 0) %>

                          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                            <div>
                              <p class="text-sm font-semibold text-gray-900">
                                {line.sku_code} — {line.sku_name}
                              </p>
                              <p class="text-xs text-gray-600 mt-1">
                                Remaining to pick:
                                <span class="font-semibold text-gray-900">{remaining_to_target}</span> {line.uom} • Target:
                                <span class="font-semibold text-gray-900">{target}</span>
                                • Temperature:
                                <span class="font-semibold text-gray-900">{line.temp_zone}</span>
                              </p>
                              <p class="text-xs text-gray-600 mt-2">
                                Recommended: pick the earliest expiry lot first unless there is an operational exception.
                              </p>
                            </div>

                            <form phx-change="select_lot" class="w-full sm:w-72">
                              <label class="block text-sm font-medium text-gray-700 mb-1.5">
                                Preferred lot to pick (FEFO first)
                              </label>
                              <input type="hidden" name="sku" value={@active_sku} />
                              <select
                                name="lot_id"
                                class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                              >
                                <%= for lot <- Enum.sort_by(inv_remaining.lots, &parse_date_days(&1.expiry_date)) do %>
                                  <option value={lot.lot_id} selected={@active_lot_id == lot.lot_id}>
                                    {lot.lot_id} • Exp {lot.expiry_date} • Avail {lot.available_units} • {lot.location} / {lot.bin}
                                  </option>
                                <% end %>
                              </select>
                            </form>
                          </div>

                          <div class="mt-4 rounded-lg border border-blue-200 bg-blue-50 p-4">
                            <div class="flex items-start space-x-2">
                              <.pps_icon
                                name="alert_triangle"
                                class="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5"
                              />
                              <div class="text-sm text-blue-900">
                                <p class="font-medium mb-1">FEFO Enforcement Active</p>
                                <p class="text-blue-800 text-xs">
                                  Scanning a later-expiry lot will show a warning (demo still allows it to proceed).
                                </p>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </.pps_card>

                      <.pps_card title="📷 Scan to Pick (selected SKU)">
                        <%= if is_nil(@active_sku) do %>
                          <p class="text-sm text-gray-600">Select a line item to enable scanning.</p>
                        <% else %>
                          <% line = find_line(@selected_order, @active_sku) %>
                          <% inv_remaining = Map.get(@inventory_by_sku, @active_sku, %{lots: []}) %>
                          <% inv_original =
                            Map.get(@inventory_by_sku_original, @active_sku, inv_remaining) %>
                          <% picked = Map.get(@picks_by_sku, @active_sku, 0) %>
                          <% target = line_target_qty(line, inv_original) %>

                          <div class="space-y-4">
                            <div class="rounded-lg border border-gray-200 bg-gray-50 p-4">
                              <p class="text-sm font-semibold text-gray-900">
                                Ready to scan for <span class="font-bold">{line.sku_code}</span>
                              </p>
                              <p class="text-xs text-gray-600 mt-1">
                                Preferred lot:
                                <span class="font-semibold text-gray-900">
                                  {@active_lot_id || "—"}
                                </span>
                                • Remaining on hand:
                                <span class="font-semibold text-gray-900">
                                  {inv_total_available(inv_remaining)}
                                </span>
                              </p>

                              <div class="mt-3 flex justify-between text-sm">
                                <span class="text-gray-700">
                                  Progress: {picked} / {target} units picked
                                </span>
                                <span class="font-semibold text-gray-900">
                                  {pct(picked, target)}%
                                </span>
                              </div>
                              <div class="mt-2">
                                <.pps_progress_bar value={picked} max={target} />
                              </div>
                            </div>

                            <.pps_button
                              variant="primary"
                              phx-click="open_scanner"
                              disabled={picked >= target}
                            >
                              Scan to Pick (Demo)
                            </.pps_button>

                            <%= if @last_scan do %>
                              <div class={[
                                "p-3 rounded-lg border",
                                if(@last_scan.result == "ok",
                                  do: "bg-green-50 border-green-200",
                                  else: "bg-amber-50 border-amber-200"
                                )
                              ]}>
                                <div class="flex items-start space-x-2 text-sm">
                                  <.pps_icon
                                    name={
                                      if(@last_scan.result == "ok",
                                        do: "check_circle",
                                        else: "alert_triangle"
                                      )
                                    }
                                    class={
                                      if(@last_scan.result == "ok",
                                        do: "w-4 h-4 text-green-600 mt-0.5",
                                        else: "w-4 h-4 text-amber-600 mt-0.5"
                                      )
                                    }
                                  />
                                  <div class="flex-1">
                                    <p class={
                                      if(@last_scan.result == "ok",
                                        do: "font-semibold text-green-900",
                                        else: "font-semibold text-amber-900"
                                      )
                                    }>
                                      Last Pick: {@last_scan.unit_code}
                                    </p>
                                    <p class={
                                      if(@last_scan.result == "ok",
                                        do: "text-xs text-green-700",
                                        else: "text-xs text-amber-800"
                                      )
                                    }>
                                      Lot: {@last_scan.lot_id}, Expiry: {@last_scan.expiry_date}
                                      <%= if @last_scan.fefo_match do %>
                                        (matches FEFO ✓)
                                      <% else %>
                                        (later than FEFO lot ⚠)
                                      <% end %>
                                    </p>
                                    <p class={
                                      if(@last_scan.result == "ok",
                                        do: "text-xs text-green-700",
                                        else: "text-xs text-amber-800"
                                      )
                                    }>
                                      Location: {@last_scan.location}, Bin {@last_scan.bin} • Lot remaining: {@last_scan.lot_remaining}
                                    </p>
                                  </div>
                                </div>
                              </div>
                            <% end %>

                            <div class="text-xs text-gray-600">
                              Demo behavior: “Scan to Pick” opens a modal with an autofocus input. Type any string and press Enter to simulate a scan.
                            </div>
                          </div>
                        <% end %>
                      </.pps_card>
                    </div>
                  </div>

                  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                    <div class="text-sm text-gray-600">
                      <span class="font-semibold text-gray-900">Overall:</span>
                      {overall_picked(@selected_order, @picks_by_sku)} / {overall_target(
                        @selected_order,
                        @inventory_by_sku_original
                      )} units picked
                      <span class="ml-2 font-semibold text-gray-900">
                        {overall_pct(@selected_order, @picks_by_sku, @inventory_by_sku_original)}%
                      </span>
                    </div>

                    <div class="flex justify-end">
                      <.pps_button
                        variant="primary"
                        phx-click="set_step"
                        phx-value-step="pack"
                        disabled={
                          not all_lines_picked?(
                            @selected_order,
                            @picks_by_sku,
                            @inventory_by_sku_original
                          )
                        }
                      >
                        Complete Pick → Pack
                        <span class="ml-2 inline-flex">
                          <.pps_icon name="arrow_right" class="w-4 h-4 text-white" />
                        </span>
                      </.pps_button>
                    </div>
                  </div>
                </div>
              <% end %>
              
    <!-- Pack Step -->
              <%= if @step == "pack" do %>
                <div class="space-y-6">
                  <.pps_card title="📦 Packing Summary (picked quantities + lots)">
                    <div class="space-y-3 mb-6">
                      <%= for line <- @selected_order.lines do %>
                        <% picked = Map.get(@picks_by_sku, line.sku_code, 0) %>
                        <% lots_label = allocation_label(@lot_allocations_by_sku, line.sku_code) %>

                        <div class="p-3 bg-gray-50 rounded-lg border border-gray-200">
                          <p class="text-sm text-gray-700">
                            <span class="font-semibold text-gray-900">{picked}x {line.sku_code}</span>
                            — {line.sku_name}
                            <span class="text-gray-600">({lots_label})</span>
                          </p>
                        </div>
                      <% end %>

                      <div class="flex flex-wrap justify-between gap-2 text-sm font-semibold">
                        <span>Total:</span>
                        <span>
                          {overall_picked(@selected_order, @picks_by_sku)} units, {format_kg(
                            total_weight_kg(@selected_order, @picks_by_sku)
                          )} kg
                        </span>
                      </div>
                    </div>

                    <form
                      phx-change="set_pack_field"
                      class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6"
                    >
                      <.pps_input label="Box Size" name="box_size" value={@pack_form["box_size"]} />
                      <.pps_input
                        label="Ice Packs"
                        name="ice_packs"
                        type="number"
                        value={@pack_form["ice_packs"]}
                      />

                      <div class="flex items-center space-x-2 pt-7">
                        <input
                          type="checkbox"
                          name="insulation"
                          value="true"
                          checked={@pack_form["insulation"] == "true"}
                          class="rounded border-gray-300 text-[#2E7D32] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        />
                        <span class="text-sm text-gray-700">Insulation</span>
                      </div>
                    </form>

                    <div class="p-4 bg-green-50 border border-green-200 rounded-lg">
                      <div class="flex items-center space-x-3">
                        <.pps_icon name="thermometer" class="w-5 h-5 text-green-600" />
                        <div class="flex-1">
                          <p class="text-sm font-semibold text-green-900">❄️ Cold Chain Compliance</p>
                          <p class="text-xs text-green-700">
                            ⏱️ Time out of refrigeration: {@cold_chain_timer_minutes} minutes (within 30-min limit ✓)
                          </p>
                        </div>
                      </div>
                    </div>

                    <div class="flex flex-col sm:flex-row gap-3 mt-6">
                      <.pps_button variant="secondary" class="flex-1">
                        <span class="mr-2 inline-flex">
                          <.pps_icon name="printer" class="w-4 h-4 text-gray-700" />
                        </span>
                        Print Packing Slip
                      </.pps_button>
                      <.pps_button variant="secondary" class="flex-1">
                        <span class="mr-2 inline-flex">
                          <.pps_icon name="printer" class="w-4 h-4 text-gray-700" />
                        </span>
                        Print Shipping Label
                      </.pps_button>
                    </div>
                  </.pps_card>

                  <div class="flex flex-col sm:flex-row sm:justify-between gap-3">
                    <.pps_button variant="secondary" phx-click="set_step" phx-value-step="pick">
                      ← Back to Pick
                    </.pps_button>

                    <.pps_button variant="primary" phx-click="set_step" phx-value-step="ship">
                      Confirm Pack → Ship
                      <span class="ml-2 inline-flex">
                        <.pps_icon name="arrow_right" class="w-4 h-4 text-white" />
                      </span>
                    </.pps_button>
                  </div>
                </div>
              <% end %>
              
    <!-- Ship Step -->
              <%= if @step == "ship" do %>
                <div class="space-y-6">
                  <.pps_card title="🚚 Ship Order">
                    <form phx-change="set_ship_field" class="space-y-4 mb-6">
                      <.pps_input
                        label="Carrier"
                        name="carrier"
                        value={@ship_form["carrier"]}
                        readonly
                      />
                      <.pps_input
                        label="Tracking Number"
                        name="tracking_number"
                        placeholder="Enter tracking number..."
                        value={@ship_form["tracking_number"]}
                      />
                      <.pps_input
                        label="Shipment Date"
                        name="shipment_date"
                        type="date"
                        value={@ship_form["shipment_date"]}
                      />

                      <div class="pt-4 border-t border-gray-200">
                        <p class="text-sm font-semibold text-gray-900 mb-3">
                          👥 Two-Person Verification (for high-value orders &gt; $500)
                        </p>

                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                          <.pps_input
                            label="Packed By"
                            name="packed_by"
                            value={@ship_form["packed_by"]}
                            readonly
                          />

                          <div>
                            <label class="block text-sm font-medium text-gray-700 mb-1.5">
                              Verified By
                            </label>
                            <.pps_button
                              variant="secondary"
                              class="w-full"
                              phx-click="noop_verify_badge"
                            >
                              Scan Supervisor Badge
                            </.pps_button>
                            <p class="mt-2 text-xs text-gray-500">
                              (demo: no-op; integrate badge scan hardware later)
                            </p>
                          </div>
                        </div>
                      </div>
                    </form>

                    <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg mb-6">
                      <p class="text-sm text-blue-900">
                        <span class="font-semibold">Note:</span>
                        Completing shipment will create signed stock movement events and trigger the
                        <code class="bg-blue-100 px-1 rounded mx-1">order.fulfilled</code>
                        webhook to your e-commerce store.
                      </p>
                    </div>
                  </.pps_card>

                  <div class="flex flex-col sm:flex-row sm:justify-between gap-3">
                    <.pps_button variant="secondary" phx-click="set_step" phx-value-step="pack">
                      ← Back to Pack
                    </.pps_button>

                    <.pps_button variant="primary" phx-click="complete_shipment">
                      <span class="mr-2 inline-flex">
                        <.pps_icon name="check_circle" class="w-4 h-4 text-white" />
                      </span>
                      ✅ Complete Shipment & Record
                    </.pps_button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </main>
    </div>

    <!-- Scanner Modal (Demo) -->
    <%= if @scan_open do %>
      <div
        class="fixed inset-0 z-50"
        phx-window-keydown="close_scanner"
        phx-key="escape"
        role="dialog"
        aria-modal="true"
      >
        <div class="absolute inset-0 bg-black/40" phx-click="close_scanner"></div>

        <div class="relative mx-auto mt-6 sm:mt-10 w-full max-w-lg px-4">
          <div class="rounded-2xl bg-white shadow-xl border border-gray-200 overflow-hidden">
            <div class="flex items-start justify-between gap-3 px-5 py-4 border-b border-gray-200">
              <div class="min-w-0">
                <p class="text-sm font-semibold text-gray-900">Scanner Demo</p>
                <p class="text-xs text-gray-600 mt-1">
                  <%= if @active_sku do %>
                    Scanning for <span class="font-semibold text-gray-900">{@active_sku}</span>
                    • Preferred lot:
                    <span class="font-semibold text-gray-900">{@active_lot_id || "—"}</span>
                  <% else %>
                    No SKU selected
                  <% end %>
                </p>
              </div>

              <button
                type="button"
                class="rounded-lg p-2 text-gray-600 hover:bg-gray-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                phx-click="close_scanner"
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            <div class="px-5 py-5 space-y-4">
              <%= if is_nil(@active_sku) do %>
                <div class="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
                  Select a SKU line first, then open the scanner.
                </div>
              <% else %>
                <form phx-submit="scan" phx-change="scan_change" class="space-y-3">
                  <label class="block text-sm font-medium text-gray-700">
                    Scan unit QR code
                    <span class="text-xs text-gray-500 font-normal">
                      (type anything, press Enter)
                    </span>
                  </label>

                  <input
                    name="scan_code"
                    value={@scan_code}
                    placeholder="Scan unit QR code..."
                    autofocus
                    autocomplete="off"
                    class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                  />

                  <div class="flex flex-col sm:flex-row gap-2">
                    <.pps_button variant="primary" type="submit" class="w-full sm:w-auto">
                      Scan
                    </.pps_button>

                    <.pps_button
                      variant="secondary"
                      type="button"
                      class="w-full sm:w-auto"
                      phx-click="demo_scan"
                    >
                      Demo Scan (auto-code)
                    </.pps_button>

                    <.pps_button
                      variant="ghost"
                      type="button"
                      class="w-full sm:w-auto"
                      phx-click="close_scanner"
                    >
                      Close
                    </.pps_button>
                  </div>
                </form>

                <div class="text-xs text-gray-600">
                  Demo notes: We decrement lot availability and track allocations per lot as scans occur.
                </div>
              <% end %>
            </div>
          </div>

          <div class="mt-3 text-center text-xs text-gray-200">
            Press ESC to close
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ----------------------------
  # Events (TopBar)
  # ----------------------------

  @impl true
  def handle_event("topbar_search", %{"query" => q}, socket) do
    {:noreply, assign(socket, :q, q)}
  end

  # ----------------------------
  # Events (Workflow)
  # ----------------------------

  @impl true
  def handle_event("cancel_order", _params, socket) do
    {:noreply,
     socket
     |> clear_workflow()
     |> push_navigate(to: ~p"/finished-goods/fulfill")}
  end

  @impl true
  def handle_event("set_step", %{"step" => step}, socket) when step in @steps do
    {:noreply, assign(socket, :step, step)}
  end

  @impl true
  def handle_event("select_line", %{"sku" => sku}, socket) do
    inv = Map.get(socket.assigns.inventory_by_sku, sku, %{lots: []})
    lot_id = inv |> fefo_lot() |> then(&(&1 && &1.lot_id))

    {:noreply,
     socket
     |> assign(:active_sku, sku)
     |> assign(:active_lot_id, lot_id)
     |> assign(:last_scan, nil)
     |> assign(:scan_code, "")}
  end

  @impl true
  def handle_event("select_lot", %{"sku" => sku, "lot_id" => lot_id}, socket) do
    {:noreply,
     socket
     |> assign(:active_sku, sku)
     |> assign(:active_lot_id, lot_id)}
  end

  @impl true
  def handle_event("open_scanner", _params, socket) do
    socket =
      socket
      |> ensure_active_line_selected()
      |> assign(:scan_open, true)
      |> assign(:scan_code, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_scanner", _params, socket) do
    {:noreply, assign(socket, :scan_open, false)}
  end

  @impl true
  def handle_event("scan_change", %{"scan_code" => code}, socket) do
    {:noreply, assign(socket, :scan_code, code)}
  end

  @impl true
  def handle_event("demo_scan", _params, socket) do
    code = "UNIT-MOCK-#{:rand.uniform(999_999)}"
    {:noreply, do_scan(socket, code)}
  end

  @impl true
  def handle_event("scan", %{"scan_code" => code}, socket) do
    {:noreply, do_scan(socket, code)}
  end

  @impl true
  def handle_event("set_pack_field", params, socket) do
    pack_form =
      socket.assigns.pack_form
      |> Map.merge(params)
      |> Map.update("insulation", "false", fn v -> if(v == "true", do: "true", else: "false") end)

    {:noreply, assign(socket, :pack_form, pack_form)}
  end

  @impl true
  def handle_event("set_ship_field", params, socket) do
    {:noreply, assign(socket, :ship_form, Map.merge(socket.assigns.ship_form, params))}
  end

  @impl true
  def handle_event("noop_verify_badge", _params, socket) do
    {:noreply, put_flash(socket, :info, "Supervisor badge scan (no-op).")}
  end

  @impl true
  def handle_event("complete_shipment", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Order shipped successfully! (mock)")
     |> clear_workflow()
     |> push_navigate(to: ~p"/finished-goods/fulfill")}
  end

  # ----------------------------
  # Scan/Pick logic (FEFO + lot consumption)
  # ----------------------------

  defp do_scan(socket, code) do
    order = socket.assigns.selected_order
    sku = socket.assigns.active_sku

    cond do
      is_nil(order) ->
        put_flash(socket, :error, "Select an order before scanning.")

      is_nil(sku) ->
        put_flash(socket, :error, "Select a SKU line before scanning.")

      true ->
        line = find_line(order, sku)
        inv_original = Map.get(socket.assigns.inventory_by_sku_original, sku, %{lots: []})
        target = line_target_qty(line, inv_original)
        picked = Map.get(socket.assigns.picks_by_sku, sku, 0)

        cond do
          picked >= target ->
            socket
            |> assign(:scan_code, "")
            |> put_flash(
              :info,
              "#{sku} is already at target picked quantity (#{target}/#{target})."
            )

          true ->
            preferred_lot_id = socket.assigns.active_lot_id
            unit_code = normalize_unit_code(code)

            case pick_one_unit(socket, sku, preferred_lot_id, unit_code) do
              {:ok, socket} ->
                socket |> assign(:scan_code, "")

              {:no_stock, socket} ->
                socket
                |> assign(:scan_code, "")
                |> put_flash(:error, "No remaining stock available to pick for #{sku}.")
            end
        end
    end
  end

  defp pick_one_unit(socket, sku, preferred_lot_id, unit_code) do
    inv = Map.get(socket.assigns.inventory_by_sku, sku, %{lots: []})
    lots = Enum.sort_by(inv.lots, &parse_date_days(&1.expiry_date))

    fefo = fefo_lot(%{inv | lots: lots})
    preferred = Enum.find(lots, &(&1.lot_id == preferred_lot_id)) || fefo

    chosen =
      cond do
        preferred && preferred.available_units > 0 -> preferred
        fefo && fefo.available_units > 0 -> fefo
        true -> nil
      end

    if is_nil(chosen) do
      {:no_stock, socket}
    else
      new_lots =
        Enum.map(lots, fn l ->
          if l.lot_id == chosen.lot_id do
            %{l | available_units: max(l.available_units - 1, 0)}
          else
            l
          end
        end)

      inventory_by_sku = Map.put(socket.assigns.inventory_by_sku, sku, %{inv | lots: new_lots})

      picks_by_sku =
        Map.update(socket.assigns.picks_by_sku, sku, 1, fn v -> v + 1 end)

      lot_allocations_by_sku =
        socket.assigns.lot_allocations_by_sku
        |> Map.update(sku, %{chosen.lot_id => 1}, fn allocs ->
          Map.update(allocs, chosen.lot_id, 1, fn v -> v + 1 end)
        end)

      fefo_match = fefo && chosen.lot_id == fefo.lot_id

      lot_remaining =
        (Enum.find(new_lots, &(&1.lot_id == chosen.lot_id)) || chosen).available_units

      last_scan = %{
        result: if(fefo_match, do: "ok", else: "warn"),
        unit_code: unit_code,
        sku: sku,
        lot_id: chosen.lot_id,
        expiry_date: chosen.expiry_date,
        location: chosen.location,
        bin: chosen.bin,
        fefo_match: fefo_match,
        lot_remaining: lot_remaining
      }

      socket =
        socket
        |> assign(:inventory_by_sku, inventory_by_sku)
        |> assign(:picks_by_sku, picks_by_sku)
        |> assign(:lot_allocations_by_sku, lot_allocations_by_sku)
        |> assign(:last_scan, last_scan)
        |> maybe_advance_active_lot(sku)

      {:ok, socket}
    end
  end

  defp maybe_advance_active_lot(socket, sku) do
    inv = Map.get(socket.assigns.inventory_by_sku, sku, %{lots: []})
    lots = Enum.sort_by(inv.lots, &parse_date_days(&1.expiry_date))

    if socket.assigns.active_sku == sku do
      active_lot_id = socket.assigns.active_lot_id
      active_lot = Enum.find(lots, &(&1.lot_id == active_lot_id))

      cond do
        is_nil(active_lot) ->
          next = Enum.find(lots, &(&1.available_units > 0)) || List.first(lots)
          assign(socket, :active_lot_id, next && next.lot_id)

        active_lot.available_units > 0 ->
          socket

        true ->
          next = Enum.find(lots, &(&1.available_units > 0)) || List.first(lots)
          assign(socket, :active_lot_id, next && next.lot_id)
      end
    else
      socket
    end
  end

  # ----------------------------
  # State helpers
  # ----------------------------

  defp load_order(socket, order) do
    picks_by_sku = Map.new(order.lines, fn l -> {l.sku_code, 0} end)

    {active_sku, active_lot_id} =
      case order.lines do
        [first | _] ->
          inv = Map.get(socket.assigns.inventory_by_sku, first.sku_code, %{lots: []})
          lot = inv |> fefo_lot() |> then(&(&1 && &1.lot_id))
          {first.sku_code, lot}

        _ ->
          {nil, nil}
      end

    socket
    |> clear_workflow()
    |> assign(:selected_order, order)
    |> assign(:step, "pick")
    |> assign(:picks_by_sku, picks_by_sku)
    |> assign(:lot_allocations_by_sku, %{})
    |> assign(:active_sku, active_sku)
    |> assign(:active_lot_id, active_lot_id)
  end

  defp clear_workflow(socket) do
    socket
    |> assign(:selected_order, nil)
    |> assign(:step, "pick")
    |> assign(:active_sku, nil)
    |> assign(:active_lot_id, nil)
    |> assign(:scan_open, false)
    |> assign(:scan_code, "")
    |> assign(:last_scan, nil)
    |> assign(:picks_by_sku, %{})
    |> assign(:lot_allocations_by_sku, %{})
    |> assign(:inventory_by_sku, deep_copy_inventory(socket.assigns.inventory_by_sku_original))
  end

  defp ensure_active_line_selected(socket) do
    cond do
      not is_nil(socket.assigns.active_sku) ->
        socket

      is_nil(socket.assigns.selected_order) ->
        socket

      true ->
        case socket.assigns.selected_order.lines do
          [first | _] ->
            inv = Map.get(socket.assigns.inventory_by_sku, first.sku_code, %{lots: []})
            lot_id = inv |> fefo_lot() |> then(&(&1 && &1.lot_id))

            socket
            |> assign(:active_sku, first.sku_code)
            |> assign(:active_lot_id, lot_id)

          _ ->
            socket
        end
    end
  end

  # ----------------------------
  # Function components (prefixed to avoid CoreComponents conflicts)
  # ----------------------------

  attr :title, :string, default: nil
  slot :inner_block, required: true

  def pps_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-sm border border-gray-200">
      <%= if @title do %>
        <div class="px-6 pt-6">
          <h3 class="text-base font-bold text-gray-900">{@title}</h3>
        </div>
      <% end %>
      <div class="p-6">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :variant, :string, default: "neutral"
  slot :inner_block, required: true

  def pps_badge(assigns) do
    class =
      case assigns.variant do
        "danger" -> "bg-red-100 text-red-800 border border-red-200"
        "success" -> "bg-green-100 text-green-800 border border-green-200"
        "warning" -> "bg-amber-100 text-amber-800 border border-amber-200"
        _ -> "bg-gray-100 text-gray-800 border border-gray-200"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={["inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold", @class]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pps_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap font-semibold transition " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
        "disabled:opacity-50 disabled:pointer-events-none"

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 rounded-full"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"
        _ -> "bg-[#2E7D32] text-white rounded-full"
      end

    size =
      case assigns.size do
        "sm" -> "h-8 px-3 text-xs"
        _ -> "h-9 px-4 text-sm"
      end

    assigns =
      assigns
      |> assign(
        :btn_class,
        Enum.join(Enum.reject([base, variant, size, assigns.class], &is_nil/1), " ")
      )

    ~H"""
    <button type={@type} class={@btn_class} disabled={@disabled} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :navigate, :any, required: true
  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def pps_link_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap font-semibold transition " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 rounded-full"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"
        _ -> "bg-[#2E7D32] text-white rounded-full"
      end

    size =
      case assigns.size do
        "sm" -> "h-8 px-3 text-xs"
        _ -> "h-9 px-4 text-sm"
      end

    assigns =
      assigns
      |> assign(
        :link_class,
        Enum.join(Enum.reject([base, variant, size, assigns.class], &is_nil/1), " ")
      )

    ~H"""
    <.link navigate={@navigate} class={@link_class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, default: nil
  attr :type, :string, default: "text"
  attr :value, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :readonly, :boolean, default: false

  def pps_input(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1.5">{@label}</label>
      <input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        readonly={@readonly}
        class={[
          "w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
          if(@readonly, do: "bg-gray-50 text-gray-700", else: "")
        ]}
      />
    </div>
    """
  end

  attr :value, :integer, required: true
  attr :max, :integer, required: true

  def pps_progress_bar(assigns) do
    pct =
      if assigns.max <= 0 do
        0
      else
        round(min(assigns.value / assigns.max, 1) * 100)
      end

    assigns = assign(assigns, :pct, pct)

    ~H"""
    <div class="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
      <div class="h-2 bg-blue-600 rounded-full" style={"width: #{@pct}%"} />
    </div>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "w-5 h-5 text-gray-600"

  def pps_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "truck" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 16V6a2 2 0 0 1 2-2h10v12H3Z" />
          <path d="M15 8h4l2 3v5h-6V8Z" />
          <path d="M7 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
          <path d="M17 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
        </svg>
      <% "user" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M20 21a8 8 0 1 0-16 0" />
          <path d="M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z" />
        </svg>
      <% "package" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 16V8a2 2 0 0 0-1-1.73L13 2.27a2 2 0 0 0-2 0L4 6.27A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z" />
          <path d="M3.3 7L12 12l8.7-5" />
          <path d="M12 22V12" />
        </svg>
      <% "clock" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 22a10 10 0 1 0-10-10 10 10 0 0 0 10 10Z" />
          <path d="M12 6v6l4 2" />
        </svg>
      <% "check_circle" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M22 12a10 10 0 1 1-10-10 10 10 0 0 1 10 10Z" />
          <path d="M8 12l3 3 5-6" />
        </svg>
      <% "alert_triangle" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M10.3 3.6 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.6a2 2 0 0 0-3.4 0Z" />
          <path d="M12 9v4" />
          <path d="M12 17h.01" />
        </svg>
      <% "thermometer" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 14.8V5a2 2 0 0 0-4 0v9.8a4 4 0 1 0 4 0Z" />
          <path d="M12 9v6" />
        </svg>
      <% "printer" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M6 9V2h12v7" />
          <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
          <path d="M6 14h12v8H6z" />
        </svg>
      <% "arrow_right" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M5 12h14" />
          <path d="M13 5l7 7-7 7" />
        </svg>
      <% _ -> %>
        <span class={@class} />
    <% end %>
    """
  end

  # ----------------------------
  # UI helpers
  # ----------------------------

  defp step_completed?(current_step, step) do
    Enum.find_index(@steps, &(&1 == step)) < Enum.find_index(@steps, &(&1 == current_step))
  end

  defp step_class(current_step, step, idx) do
    current_idx = Enum.find_index(@steps, &(&1 == current_step))

    cond do
      current_step == step -> "bg-blue-600 text-white"
      idx < current_idx -> "bg-green-600 text-white"
      true -> "bg-gray-200 text-gray-600"
    end
  end

  defp pct(value, max) when is_integer(value) and is_integer(max) do
    if max <= 0, do: 0, else: round(min(value / max, 1) * 100)
  end

  defp inv_total_available(inv) do
    (inv.lots || []) |> Enum.map(& &1.available_units) |> Enum.sum()
  end

  defp parse_date_days(iso) do
    case Date.from_iso8601(to_string(iso)) do
      {:ok, d} -> Date.to_gregorian_days(d)
      _ -> 9_999_999
    end
  end

  defp fefo_lot(inv) do
    inv.lots
    |> Enum.sort_by(&parse_date_days(&1.expiry_date))
    |> Enum.find(&(&1.available_units > 0)) || List.first(inv.lots)
  end

  defp fefo_lot_label(inv) do
    case fefo_lot(inv) do
      nil -> "—"
      lot -> "#{lot.lot_id} (exp #{lot.expiry_date})"
    end
  end

  defp find_line(order, sku), do: Enum.find(order.lines, &(&1.sku_code == sku))

  defp line_target_qty(line, inv_original) do
    on_hand = inv_total_available(inv_original)
    min(line.ordered_qty, on_hand)
  end

  defp overall_target(order, inventory_by_sku_original) do
    order.lines
    |> Enum.map(fn l ->
      inv_original = Map.get(inventory_by_sku_original, l.sku_code, %{lots: []})
      line_target_qty(l, inv_original)
    end)
    |> Enum.sum()
  end

  defp overall_picked(order, picks_by_sku) do
    order.lines
    |> Enum.map(fn l -> Map.get(picks_by_sku, l.sku_code, 0) end)
    |> Enum.sum()
  end

  defp overall_pct(order, picks_by_sku, inventory_by_sku_original) do
    pct(overall_picked(order, picks_by_sku), overall_target(order, inventory_by_sku_original))
  end

  defp all_lines_picked?(order, picks_by_sku, inventory_by_sku_original) do
    Enum.all?(order.lines, fn l ->
      inv_original = Map.get(inventory_by_sku_original, l.sku_code, %{lots: []})
      target = line_target_qty(l, inv_original)
      Map.get(picks_by_sku, l.sku_code, 0) >= target
    end)
  end

  defp total_weight_kg(order, picks_by_sku) do
    order.lines
    |> Enum.map(fn l -> Map.get(picks_by_sku, l.sku_code, 0) * l.unit_weight_kg end)
    |> Enum.sum()
  end

  defp format_kg(value) when is_number(value),
    do: :erlang.float_to_binary(value * 1.0, decimals: 1)

  defp normalize_unit_code(code) do
    code = String.trim(to_string(code))
    if code == "", do: "UNIT-MOCK-#{:rand.uniform(999_999)}", else: code
  end

  defp allocation_label(lot_allocations_by_sku, sku) do
    allocs = Map.get(lot_allocations_by_sku, sku, %{})

    if map_size(allocs) == 0 do
      "no lots picked yet"
    else
      allocs
      |> Enum.sort_by(fn {lot_id, _qty} -> lot_id end)
      |> Enum.map(fn {lot_id, qty} -> "#{lot_id} x #{qty}" end)
      |> Enum.join(", ")
    end
  end

  defp deep_copy_inventory(inv_map) do
    Map.new(inv_map, fn {sku, inv} ->
      lots =
        inv.lots
        |> Enum.map(fn l ->
          %{
            lot_id: l.lot_id,
            expiry_date: l.expiry_date,
            location: l.location,
            bin: l.bin,
            available_units: l.available_units
          }
        end)

      {sku, %{lots: lots}}
    end)
  end

  # ----------------------------
  # Mock data
  # ----------------------------

  defp mock_orders do
    [
      %{
        id: "ORD-5678",
        customer: "FreshMart SG",
        priority: "standard",
        due_date: "2024-12-16",
        status: "ready",
        lines: [
          %{
            sku_code: "LZ-500",
            sku_name: "Fruit Purée (Chilled)",
            ordered_qty: 10,
            uom: "units",
            unit_weight_kg: 0.45,
            temp_zone: "chilled"
          },
          %{
            sku_code: "AP-100",
            sku_name: "Apple Sauce (Ambient)",
            ordered_qty: 6,
            uom: "units",
            unit_weight_kg: 0.30,
            temp_zone: "ambient"
          },
          %{
            sku_code: "BN-210",
            sku_name: "Banana Slices (Frozen)",
            ordered_qty: 4,
            uom: "units",
            unit_weight_kg: 0.55,
            temp_zone: "frozen"
          }
        ]
      },
      %{
        id: "ORD-5679",
        customer: "GreenGrocer MY",
        priority: "urgent",
        due_date: "2024-12-15",
        status: "ready",
        lines: [
          %{
            sku_code: "LZ-500",
            sku_name: "Fruit Purée (Chilled)",
            ordered_qty: 10,
            uom: "units",
            unit_weight_kg: 0.45,
            temp_zone: "chilled"
          },
          %{
            sku_code: "GR-330",
            sku_name: "Green Blend (Chilled)",
            ordered_qty: 5,
            uom: "units",
            unit_weight_kg: 0.40,
            temp_zone: "chilled"
          }
        ]
      },
      %{
        id: "ORD-5680",
        customer: "Online Store",
        priority: "standard",
        due_date: "2024-12-17",
        status: "reserved",
        lines: [
          %{
            sku_code: "LZ-500",
            sku_name: "Fruit Purée (Chilled)",
            ordered_qty: 10,
            uom: "units",
            unit_weight_kg: 0.45,
            temp_zone: "chilled"
          },
          %{
            sku_code: "PK-010",
            sku_name: "Ice Pack (Accessory)",
            ordered_qty: 2,
            uom: "units",
            unit_weight_kg: 0.20,
            temp_zone: "ambient"
          },
          %{
            sku_code: "BX-200",
            sku_name: "Insulated Box (Packaging)",
            ordered_qty: 1,
            uom: "unit",
            unit_weight_kg: 0.80,
            temp_zone: "ambient"
          }
        ]
      }
    ]
  end

  defp mock_inventory do
    %{
      "LZ-500" => %{
        lots: [
          %{
            lot_id: "LOT-089",
            expiry_date: "2024-12-20",
            location: "Purée Fridge",
            bin: "A-12",
            available_units: 23
          },
          %{
            lot_id: "LOT-090",
            expiry_date: "2024-12-27",
            location: "Purée Fridge",
            bin: "A-14",
            available_units: 12
          }
        ]
      },
      "AP-100" => %{
        lots: [
          %{
            lot_id: "LOT-201",
            expiry_date: "2025-01-10",
            location: "Ambient Rack",
            bin: "C-03",
            available_units: 18
          },
          %{
            lot_id: "LOT-199",
            expiry_date: "2025-02-01",
            location: "Ambient Rack",
            bin: "C-08",
            available_units: 7
          }
        ]
      },
      "BN-210" => %{
        lots: [
          %{
            lot_id: "LOT-310",
            expiry_date: "2025-01-05",
            location: "Freezer",
            bin: "F-02",
            available_units: 3
          },
          %{
            lot_id: "LOT-311",
            expiry_date: "2025-02-12",
            location: "Freezer",
            bin: "F-04",
            available_units: 10
          }
        ]
      },
      "GR-330" => %{
        lots: [
          %{
            lot_id: "LOT-412",
            expiry_date: "2024-12-22",
            location: "Chilled Prep",
            bin: "B-01",
            available_units: 4
          },
          %{
            lot_id: "LOT-413",
            expiry_date: "2024-12-29",
            location: "Chilled Prep",
            bin: "B-02",
            available_units: 9
          }
        ]
      },
      "PK-010" => %{
        lots: [
          %{
            lot_id: "LOT-901",
            expiry_date: "2026-12-31",
            location: "Packaging Shelf",
            bin: "P-07",
            available_units: 120
          }
        ]
      },
      "BX-200" => %{
        lots: [
          %{
            lot_id: "LOT-777",
            expiry_date: "2027-12-31",
            location: "Packaging Shelf",
            bin: "P-01",
            available_units: 25
          }
        ]
      }
    }
  end
end
