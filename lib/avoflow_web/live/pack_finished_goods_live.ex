defmodule AvoflowWeb.PackFinishedGoodsLive do
  use AvoflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    packaging_skus = [
      %{id: "sku_lz500", code: "LZ-500", name: "Large ziplock", volume_ml: 500, weight_g: 450},
      %{
        id: "sku_ssb200",
        code: "SSB-200",
        name: "Small sauce bottle",
        volume_ml: 200,
        weight_g: 180
      },
      %{
        id: "sku_std300",
        code: "STD-300",
        name: "Standard sauce bottle",
        volume_ml: 300,
        weight_g: 270
      },
      %{id: "sku_sg50", code: "SG-50", name: "Small shot glass", volume_ml: 50, weight_g: 45},
      %{id: "sku_gj206", code: "GJ-206", name: "Glass jar", volume_ml: 206, weight_g: 185}
    ]

    available_runs = [
      %{
        id: "PR-2024-045",
        date: "2024-12-10",
        formulation: "Long-life",
        bulk_qty_kg: 15.2,
        status: "Released",
        lot_id: "LOT-2024-090",
        best_before: "2025-06-10",
        hard_expiry: "2025-07-10",
        ph_level: 4.2
      },
      %{
        id: "PR-2024-044",
        date: "2024-12-09",
        formulation: "Fresh",
        bulk_qty_kg: 8.5,
        status: "Released",
        lot_id: "LOT-2024-089",
        best_before: "2024-12-20",
        hard_expiry: "2024-12-25",
        ph_level: 4.3
      },
      %{
        id: "PR-2024-043",
        date: "2024-12-08",
        formulation: "Long-life",
        bulk_qty_kg: 12.0,
        status: "On-hold",
        lot_id: "LOT-2024-088",
        best_before: "2025-05-08",
        hard_expiry: "2025-06-08",
        ph_level: 4.5
      }
    ]

    socket =
      socket
      |> assign(
        # TopBar props (mock)
        q: "",
        unread_count: 3,
        user_label: "John Doe",
        # Page state
        step: 1,
        packaging_skus: packaging_skus,
        available_runs: available_runs,
        selected_run_id: nil,
        selected_run: nil,
        # %{sku_id => integer_qty}
        packing_plan: %{},
        location: "Purée Fridge",
        bin: "A-12",
        scanned_units: 0,
        scan_code: "",
        actual_weight: "",
        printer: "zebra-zd421"
      )
      |> recompute()

    {:ok, socket}
  end

  # -------------------------
  # TopBar no-op handlers
  # -------------------------

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket) do
    {:noreply, assign(socket, q: q)}
  end

  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_profile", _params, socket), do: {:noreply, socket}

  # -------------------------
  # Page events
  # -------------------------

  def handle_event("select_run", %{"id" => run_id}, socket) do
    socket =
      socket
      |> assign(selected_run_id: run_id, step: 2)
      |> recompute()

    {:noreply, socket}
  end

  def handle_event("go_step", %{"step" => step}, socket) do
    step_int = safe_int(step, socket.assigns.step)

    socket =
      socket
      |> assign(step: step_int)
      |> recompute()

    {:noreply, socket}
  end

  def handle_event("qty_change", %{"qty" => qty_params}, socket) do
    packing_plan =
      Enum.reduce(qty_params, socket.assigns.packing_plan, fn {sku_id, v}, acc ->
        Map.put(acc, sku_id, max(safe_int(v, 0), 0))
      end)

    socket =
      socket
      |> assign(packing_plan: packing_plan)
      |> recompute()

    {:noreply, socket}
  end

  def handle_event("set_location", %{"location" => location}, socket) do
    {:noreply, assign(socket, location: location)}
  end

  def handle_event("set_bin", %{"bin" => bin}, socket) do
    {:noreply, assign(socket, bin: bin)}
  end

  def handle_event("scan_change", %{"scan" => %{"code" => code}}, socket) do
    {:noreply, assign(socket, scan_code: code)}
  end

  def handle_event("scan", %{"scan" => %{"code" => _code}}, socket) do
    # In production: validate scanned code; here we simply increment.
    scanned_units = socket.assigns.scanned_units + 1

    socket =
      socket
      |> assign(scanned_units: scanned_units, scan_code: "")
      |> recompute()

    {:noreply, socket}
  end

  def handle_event("set_actual_weight", %{"actual" => %{"weight" => w}}, socket) do
    socket =
      socket
      |> assign(actual_weight: w)
      |> recompute()

    {:noreply, socket}
  end

  def handle_event("set_printer", %{"printer" => printer}, socket) do
    {:noreply, assign(socket, printer: printer)}
  end

  def handle_event("complete", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/finished-goods")}
  end

  # -------------------------
  # Render
  # -------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <main class="">
        <div class="">
          <div class="max-w-5xl mx-auto">
            <div class="mb-6">
              <.link
                navigate={~p"/finished-goods"}
                class="flex items-center text-sm text-gray-500 hover:text-gray-900 mb-3 transition-colors"
              >
                <.fg_svg_icon name="arrow-left" class="w-4 h-4 mr-1" /> Back to Finished Goods
              </.link>

              <h1 class="text-2xl font-bold text-gray-900">Pack Finished Goods</h1>
              <p class="text-gray-500 mt-1">Convert bulk purée into packaged SKUs</p>
            </div>

            <div class="mb-8">
              <.fg_breadcrumb items={[
                %{label: "1. Select Production Run", active: @step == 1, completed: @step > 1},
                %{label: "2. Configure Packing", active: @step == 2, completed: @step > 2},
                %{label: "3. Verify & Label", active: @step == 3, completed: false}
              ]} />
            </div>

            <%= if @step == 1 do %>
              <.fg_card title="Step 1: Select Production Run">
                <div class="space-y-4">
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 flex items-start space-x-3">
                    <.fg_svg_icon name="info" class="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
                    <div class="text-sm text-blue-900">
                      <p class="font-medium mb-1">Select a completed production run to pack</p>
                      <p class="text-blue-700">
                        Only released runs with passing QC are available for packing. The bulk purée will be divided
                        into individual packaged units.
                      </p>
                    </div>
                  </div>

                  <div class="border rounded-lg overflow-hidden">
                    <table class="w-full text-sm">
                      <thead class="bg-gray-50 border-b border-gray-200">
                        <tr>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700">Run ID</th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700">Date</th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700">Formulation</th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700">Bulk Qty</th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700">Status</th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700">Action</th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-100">
                        <%= for run <- @available_runs do %>
                          <tr class="hover:bg-gray-50 transition-colors">
                            <td class="py-3 px-4 font-medium text-gray-900">{run.id}</td>
                            <td class="py-3 px-4 text-gray-600">{run.date}</td>
                            <td class="py-3 px-4">
                              <.fg_badge variant={
                                if(run.formulation == "Long-life", do: "success", else: "warning")
                              }>
                                {run.formulation}
                              </.fg_badge>
                            </td>
                            <td class="py-3 px-4 font-medium">{run.bulk_qty_kg} kg</td>
                            <td class="py-3 px-4">
                              <.fg_badge variant={
                                if(run.status == "Released", do: "success", else: "neutral")
                              }>
                                {run.status}
                              </.fg_badge>
                            </td>
                            <td class="py-3 px-4">
                              <.fg_button
                                size="sm"
                                variant="primary"
                                disabled={run.status != "Released"}
                                phx-click="select_run"
                                phx-value-id={run.id}
                              >
                                Select
                              </.fg_button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>

                  <%= if @selected_run do %>
                    <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                      <div class="flex items-start space-x-3">
                        <.fg_svg_icon
                          name="check-circle"
                          class="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5"
                        />
                        <div class="flex-1">
                          <p class="text-sm font-semibold text-green-900 mb-2">
                            Selected: {@selected_run.id} ({@selected_run.formulation}, {@selected_run.bulk_qty_kg} kg available)
                          </p>
                          <div class="grid grid-cols-2 gap-3 text-xs text-green-800">
                            <div class="flex items-center space-x-2">
                              <.fg_svg_icon name="package" class="w-4 h-4" />
                              <span>Lot ID: {@selected_run.lot_id}</span>
                            </div>
                            <div class="flex items-center space-x-2">
                              <.fg_svg_icon name="calendar" class="w-4 h-4" />
                              <span>Best Before: {@selected_run.best_before}</span>
                            </div>
                            <div class="flex items-center space-x-2">
                              <.fg_svg_icon name="alert-circle" class="w-4 h-4" />
                              <span>Hard Expiry: {@selected_run.hard_expiry}</span>
                            </div>
                            <div class="flex items-center space-x-2">
                              <.fg_svg_icon name="beaker" class="w-4 h-4" />
                              <span>pH Level: {@selected_run.ph_level}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="flex justify-end mt-6 pt-6 border-t border-gray-200">
                  <.link navigate={~p"/finished-goods"}>
                    <.fg_button variant="secondary">Cancel</.fg_button>
                  </.link>

                  <.fg_button
                    class="ml-3"
                    variant="primary"
                    disabled={is_nil(@selected_run)}
                    phx-click="go_step"
                    phx-value-step="2"
                  >
                    <span class="inline-flex items-center">
                      Next: Configure Packing <.fg_svg_icon name="arrow-right" class="w-4 h-4 ml-2" />
                    </span>
                  </.fg_button>
                </div>
              </.fg_card>
            <% end %>

            <%= if @step == 2 and @selected_run do %>
              <.fg_card title="Step 2: Configure Packing Plan">
                <div class="space-y-6">
                  <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
                    <div class="flex items-center justify-between">
                      <div>
                        <p class="text-sm font-semibold text-gray-900">Lot: {@selected_run.lot_id}</p>
                        <p class="text-xs text-gray-600 mt-1">
                          Available: {format_int(@available_g)} g ({@selected_run.bulk_qty_kg} kg)
                        </p>
                      </div>
                      <.fg_badge variant={
                        if(@selected_run.formulation == "Long-life", do: "success", else: "warning")
                      }>
                        {@selected_run.formulation}
                      </.fg_badge>
                    </div>
                  </div>

                  <div>
                    <h4 class="text-sm font-semibold text-gray-900 mb-3">SKU Selection</h4>

                    <div class="border rounded-lg overflow-hidden">
                      <.form for={%{}} as={:plan} phx-change="qty_change">
                        <table class="w-full text-sm">
                          <thead class="bg-gray-50 border-b border-gray-200">
                            <tr>
                              <th class="text-left py-3 px-4 font-semibold text-gray-700">
                                SKU Code
                              </th>
                              <th class="text-left py-3 px-4 font-semibold text-gray-700">
                                Container Name
                              </th>
                              <th class="text-right py-3 px-4 font-semibold text-gray-700">
                                Fill Vol
                              </th>
                              <th class="text-right py-3 px-4 font-semibold text-gray-700">
                                Std Weight
                              </th>
                              <th class="text-center py-3 px-4 font-semibold text-gray-700">
                                Plan Qty
                              </th>
                              <th class="text-right py-3 px-4 font-semibold text-gray-700">
                                Required
                              </th>
                            </tr>
                          </thead>

                          <tbody class="divide-y divide-gray-100">
                            <%= for sku <- @packaging_skus do %>
                              <% qty = Map.get(@packing_plan, sku.id, 0) %>
                              <% required = qty * sku.weight_g %>
                              <tr class="hover:bg-gray-50">
                                <td class="py-3 px-4 font-medium text-gray-900">{sku.code}</td>
                                <td class="py-3 px-4 text-gray-600">{sku.name}</td>
                                <td class="py-3 px-4 text-right text-gray-600">{sku.volume_ml}ml</td>
                                <td class="py-3 px-4 text-right text-gray-600">{sku.weight_g}g</td>
                                <td class="py-3 px-4">
                                  <input
                                    type="number"
                                    min="0"
                                    name={"qty[#{sku.id}]"}
                                    value={if(qty == 0, do: "", else: qty)}
                                    placeholder="0"
                                    class="w-24 text-center rounded-lg border border-gray-300 bg-white px-2 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                                  />
                                </td>
                                <td class="py-3 px-4 text-right font-medium text-gray-900">
                                  {format_int(required)}g
                                </td>
                              </tr>
                            <% end %>
                          </tbody>

                          <tfoot class="bg-gray-50 border-t-2 border-gray-300">
                            <tr>
                              <td colspan="4" class="py-3 px-4 font-semibold text-gray-900">Total</td>
                              <td class="py-3 px-4 text-center font-bold text-gray-900">
                                {@total_units} units
                              </td>
                              <td class="py-3 px-4 text-right font-bold text-gray-900">
                                {format_int(@total_required_g)}g
                              </td>
                            </tr>
                          </tfoot>
                        </table>
                      </.form>
                    </div>
                  </div>

                  <div class={[
                    "p-4 rounded-lg border-2",
                    if(@remaining_g >= 0,
                      do: "bg-green-50 border-green-300",
                      else: "bg-red-50 border-red-300"
                    )
                  ]}>
                    <div class="space-y-2 text-sm">
                      <div class="flex justify-between">
                        <span class="text-gray-700">Total Required:</span>
                        <span class="font-semibold text-gray-900">
                          {format_int(@total_required_g)} g
                        </span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-gray-700">Available:</span>
                        <span class="font-semibold text-gray-900">{format_int(@available_g)} g</span>
                      </div>
                      <div class="flex justify-between pt-2 border-t border-gray-300">
                        <span class="font-semibold text-gray-900">Remaining:</span>
                        <span class={[
                          "font-bold",
                          if(@remaining_g >= 0, do: "text-green-700", else: "text-red-700")
                        ]}>
                          {format_int(@remaining_g)} g {if @remaining_g >= 0, do: "✓", else: "✗"}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-900 mb-1">
                        Packing Location
                      </label>
                      <select
                        name="location"
                        phx-change="set_location"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                      >
                        <%= for opt <- ["Purée Fridge", "Purée Freezer", "Dispatch Chiller"] do %>
                          <option value={opt} selected={@location == opt}>{opt}</option>
                        <% end %>
                      </select>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-900 mb-1">Bin</label>
                      <input
                        type="text"
                        name="bin"
                        value={@bin}
                        placeholder="e.g., A-12"
                        phx-change="set_bin"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                      />
                    </div>
                  </div>

                  <div class="flex items-center space-x-2 text-xs text-gray-500">
                    <.fg_svg_icon name="map-pin" class="w-4 h-4" />
                    <span>Packed By: John Doe (auto) • Device: Scanner-03</span>
                  </div>
                </div>

                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mt-6 pt-6 border-t border-gray-200">
                  <.fg_button variant="secondary" phx-click="go_step" phx-value-step="1">
                    <span class="inline-flex items-center">
                      <.fg_svg_icon name="arrow-left" class="w-4 h-4 mr-2" /> Back
                    </span>
                  </.fg_button>

                  <.fg_button
                    variant="primary"
                    disabled={not (@total_required_g > 0 and @remaining_g >= 0)}
                    phx-click="go_step"
                    phx-value-step="3"
                  >
                    <span class="inline-flex items-center">
                      Next: Verify &amp; Label
                      <.fg_svg_icon name="arrow-right" class="w-4 h-4 ml-2" />
                    </span>
                  </.fg_button>
                </div>
              </.fg_card>
            <% end %>

            <%= if @step == 3 and @selected_run do %>
              <.fg_card title="Step 3: Verify & Generate Labels">
                <div class="space-y-6">
                  <div>
                    <h4 class="text-sm font-semibold text-gray-900 mb-3">📋 Packing Summary</h4>

                    <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 space-y-3">
                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                        <div>
                          <span class="text-gray-600">Lot:</span>
                          <span class="ml-2 font-semibold text-gray-900">{@selected_run.lot_id}</span>
                        </div>
                        <div>
                          <span class="text-gray-600">Expiry:</span>
                          <span class="ml-2 font-semibold text-gray-900">
                            {@selected_run.hard_expiry}
                          </span>
                        </div>
                      </div>

                      <div class="border-t border-gray-300 pt-3 space-y-2">
                        <%= for {sku_id, qty} <- @packing_plan, qty > 0 do %>
                          <% sku = Enum.find(@packaging_skus, &(&1.id == sku_id)) %>
                          <%= if sku do %>
                            <% weight = qty * sku.weight_g %>
                            <div class="flex justify-between text-sm gap-4">
                              <span class="text-gray-700">
                                {qty}x {sku.code} ({sku.name})
                              </span>
                              <span class="font-medium text-gray-900 whitespace-nowrap">
                                → {qty} units, {format_int(weight)}g
                              </span>
                            </div>
                          <% end %>
                        <% end %>
                      </div>

                      <div class="border-t-2 border-gray-300 pt-3 flex justify-between font-bold text-gray-900">
                        <span>Total:</span>
                        <span>{@total_units} units, {format_int(@total_required_g)}g</span>
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4 class="text-sm font-semibold text-gray-900 mb-3">
                      📷 Scan Verification (Recommended)
                    </h4>

                    <.fg_card class="bg-blue-50 border-blue-200">
                      <p class="text-sm text-blue-900 mb-4">
                        Scan each unit's QR code to confirm packing and ensure traceability.
                      </p>

                      <.form for={%{}} as={:scan} phx-submit="scan" phx-change="scan_change">
                        <input
                          type="text"
                          name="scan[code]"
                          value={@scan_code}
                          placeholder="Scan unit QR code..."
                          class="w-full rounded-lg border border-blue-200 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                          autocomplete="off"
                        />
                        <div class="mt-3">
                          <.fg_button variant="primary" size="sm" class="w-full">Add Scan</.fg_button>
                        </div>
                      </.form>

                      <div class="mt-4">
                        <div class="flex justify-between text-sm mb-2">
                          <span class="text-gray-700">
                            Scanned: {@scanned_units} / {@total_units} units
                          </span>
                          <span class="font-semibold text-gray-900">{@scan_percent}%</span>
                        </div>
                        <.fg_progress_bar value={@scanned_units} max={@total_units} />
                      </div>

                      <%= if @scanned_units > 0 do %>
                        <div class="mt-3 p-2 bg-green-100 border border-green-300 rounded text-xs text-green-800">
                          Last Scan: UNIT-{hd(@packaging_skus).code}-{pad6(@scanned_units)} ✓
                        </div>
                      <% end %>

                      <div class="mt-4">
                        <.fg_button variant="secondary" size="sm" class="w-full" disabled={true}>
                          ⏭️ Skip Scanning (requires supervisor approval)
                        </.fg_button>
                      </div>
                      <p class="text-xs text-blue-900 mt-2">
                        Skipping scanning is disabled in this mock LiveView (no confirmation dialog without JS).
                      </p>
                    </.fg_card>
                  </div>

                  <div>
                    <h4 class="text-sm font-semibold text-gray-900 mb-3">🖨️ Label Printing</h4>

                    <.fg_card>
                      <div class="mb-4">
                        <label class="block text-sm font-medium text-gray-900 mb-1">Printer</label>
                        <select
                          name="printer"
                          phx-change="set_printer"
                          class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        >
                          <option value="zebra-zd421" selected={@printer == "zebra-zd421"}>
                            Zebra-ZD421 (Production Floor)
                          </option>
                          <option value="zebra-zd620" selected={@printer == "zebra-zd620"}>
                            Zebra-ZD620 (Packing Area)
                          </option>
                          <option value="dymo-450" selected={@printer == "dymo-450"}>
                            Dymo-450 (Office)
                          </option>
                        </select>
                      </div>

                      <.fg_button variant="primary" size="lg" class="w-full">
                        <span class="inline-flex items-center justify-center">
                          <.fg_svg_icon name="printer" class="w-4 h-4 mr-2" />
                          🖨️ Print {@total_units} Labels
                        </span>
                      </.fg_button>

                      <p class="text-xs text-gray-500 mt-3">
                        Label includes: QR code, SKU, Lot, Expiry, Net Weight, Batch Hash
                      </p>
                    </.fg_card>
                  </div>

                  <div>
                    <h4 class="text-sm font-semibold text-gray-900 mb-3">⚖️ Variance Handling</h4>

                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-900 mb-1">
                          Actual Weight Packed (g)
                        </label>
                        <.form for={%{}} as={:actual} phx-change="set_actual_weight">
                          <input
                            type="number"
                            name="actual[weight]"
                            value={@actual_weight}
                            placeholder={to_string(@total_required_g)}
                            class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                          />
                        </.form>
                      </div>

                      <div class="flex flex-col justify-end">
                        <div class="text-sm text-gray-600 mb-1">Variance</div>
                        <div class={[
                          "text-lg font-bold",
                          if(@variance_flag == :warn, do: "text-orange-600", else: "text-green-600")
                        ]}>
                          <%= if @variance_pct_str do %>
                            {@variance_pct_str}{if @variance_flag == :warn, do: " ⚠️", else: ""}
                          <% else %>
                            —
                          <% end %>
                        </div>
                      </div>
                    </div>

                    <%= if @variance_flag == :warn do %>
                      <div class="mt-3 p-3 bg-orange-50 border border-orange-200 rounded-lg text-sm text-orange-900">
                        <.fg_svg_icon name="alert-circle" class="w-4 h-4 inline mr-2" />
                        Variance exceeds 2% threshold. Supervisor override required.
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mt-6 pt-6 border-t border-gray-200">
                  <.fg_button variant="secondary" phx-click="go_step" phx-value-step="2">
                    <span class="inline-flex items-center">
                      <.fg_svg_icon name="arrow-left" class="w-4 h-4 mr-2" /> Back
                    </span>
                  </.fg_button>

                  <.fg_button variant="primary" size="lg" phx-click="complete">
                    <span class="inline-flex items-center">
                      <.fg_svg_icon name="check-circle" class="w-4 h-4 mr-2" />
                      ✅ Complete Packing &amp; Record
                    </span>
                  </.fg_button>
                </div>
              </.fg_card>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # -------------------------
  # Function components (prefixed to avoid CoreComponents conflicts)
  # -------------------------

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

  attr :items, :list, required: true

  def fg_breadcrumb(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center gap-2">
      <%= for {item, idx} <- Enum.with_index(@items) do %>
        <div class="flex items-center">
          <div class={[
            "text-sm",
            if(item.active, do: "font-semibold text-gray-900", else: "text-gray-500"),
            if(item.completed, do: "line-through text-gray-400", else: "")
          ]}>
            {item.label}
          </div>
          <%= if idx < length(@items) - 1 do %>
            <span class="mx-2 text-gray-300 hidden sm:inline">/</span>
          <% end %>
        </div>
      <% end %>
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
  attr :rest, :global, include: ~w(phx-click phx-value-id phx-value-step phx-disable-with type)
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

  attr :value, :integer, required: true
  attr :max, :integer, required: true

  def fg_progress_bar(assigns) do
    pct =
      cond do
        assigns.max <= 0 -> 0
        assigns.value <= 0 -> 0
        true -> min(round(assigns.value * 100 / assigns.max), 100)
      end

    assigns = assign(assigns, :pct, pct)

    ~H"""
    <div class="w-full h-2 bg-white/70 border border-blue-200 rounded-full overflow-hidden">
      <div class="h-2 bg-blue-600" style={"width: #{@pct}%"}></div>
    </div>
    """
  end

  # -------------------------
  # Derived assigns
  # -------------------------

  defp recompute(socket) do
    selected_run =
      Enum.find(socket.assigns.available_runs, fn r -> r.id == socket.assigns.selected_run_id end)

    {total_units, total_required_g} =
      Enum.reduce(socket.assigns.packing_plan, {0, 0}, fn {sku_id, qty}, {u_acc, g_acc} ->
        sku = Enum.find(socket.assigns.packaging_skus, &(&1.id == sku_id))
        qty = max(qty || 0, 0)

        if sku do
          {u_acc + qty, g_acc + qty * sku.weight_g}
        else
          {u_acc, g_acc}
        end
      end)

    available_g =
      if selected_run do
        round(selected_run.bulk_qty_kg * 1000)
      else
        0
      end

    remaining_g = available_g - total_required_g

    scan_percent =
      cond do
        total_units <= 0 -> 0
        socket.assigns.scanned_units <= 0 -> 0
        true -> min(round(socket.assigns.scanned_units * 100 / total_units), 100)
      end

    {variance_pct_str, variance_flag} =
      compute_variance(socket.assigns.actual_weight, total_required_g)

    socket
    |> assign(
      selected_run: selected_run,
      total_units: total_units,
      total_required_g: total_required_g,
      available_g: available_g,
      remaining_g: remaining_g,
      scan_percent: scan_percent,
      variance_pct_str: variance_pct_str,
      variance_flag: variance_flag
    )
  end

  defp compute_variance(actual_weight_str, total_required_g) do
    actual = safe_int(actual_weight_str, nil)

    cond do
      is_nil(actual) or total_required_g <= 0 ->
        {nil, :ok}

      true ->
        pct = (actual - total_required_g) / total_required_g * 100.0
        pct_str = :erlang.float_to_binary(pct, decimals: 1) <> "%"

        flag =
          if abs((actual - total_required_g) / total_required_g) > 0.02 do
            :warn
          else
            :ok
          end

        {pct_str, flag}
    end
  end

  defp safe_int(nil, default), do: default
  defp safe_int(v, default) when is_integer(v), do: v

  defp safe_int(v, default) when is_binary(v) do
    v = String.trim(v)

    case Integer.parse(v) do
      {i, _} -> i
      :error -> default
    end
  end

  defp format_int(i) when is_integer(i) do
    i
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  defp pad6(i) when is_integer(i) do
    i
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end
end
