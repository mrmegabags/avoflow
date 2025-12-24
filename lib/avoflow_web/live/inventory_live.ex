defmodule AvoflowWeb.InventoryLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar
  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    # Unified inventory rows: avocados + ingredients + packaging + labels + shipping
    # Notes:
    # - Lemons: track only fruit weight (kg)
    # - Other ingredients: measure by before/after container weights (kg)
    rows = [
      # Avocados (converted into a single "Inventory-style" schema)
      %{
        id: "avo-raw-ready",
        category: "Avocados",
        item: "Raw",
        location: "Ready",
        unit: "kg",
        quantity: 45.0,
        par: 500.0,
        reorder: 80.0,
        est_value_per_unit: 2.5,
        measurement: "Scale weight (kg)",
        updated_at: "Today"
      },
      %{
        id: "avo-raw-ripening",
        category: "Avocados",
        item: "Raw",
        location: "Ripening",
        unit: "kg",
        quantity: 80.0,
        par: 500.0,
        reorder: 80.0,
        est_value_per_unit: 2.5,
        measurement: "Scale weight (kg)",
        updated_at: "Today"
      },
      %{
        id: "avo-raw-unripe",
        category: "Avocados",
        item: "Raw",
        location: "Unripe",
        unit: "kg",
        quantity: 120.0,
        par: 500.0,
        reorder: 80.0,
        est_value_per_unit: 2.5,
        measurement: "Scale weight (kg)",
        updated_at: "Today"
      },
      %{
        id: "avo-puree-fridge",
        category: "Avocados",
        item: "Purée",
        location: "Fridge",
        unit: "kg",
        quantity: 12.0,
        par: 200.0,
        reorder: 25.0,
        est_value_per_unit: 4.0,
        measurement: "Scale weight (kg)",
        updated_at: "Today"
      },
      %{
        id: "avo-puree-freezer",
        category: "Avocados",
        item: "Purée",
        location: "Freezer",
        unit: "kg",
        quantity: 30.0,
        par: 200.0,
        reorder: 25.0,
        est_value_per_unit: 4.0,
        measurement: "Scale weight (kg)",
        updated_at: "Today"
      },

      # Ingredients
      %{
        id: "ing-olive-oil",
        category: "Ingredients",
        item: "Olive Oil",
        location: "Store",
        unit: "kg",
        quantity: 18.0,
        par: 50.0,
        reorder: 10.0,
        est_value_per_unit: 6.5,
        measurement: "Before/after container weight (kg)",
        updated_at: "Yesterday"
      },
      %{
        id: "ing-sodium-benzoate",
        category: "Ingredients",
        item: "Sodium Benzoate",
        location: "Store",
        unit: "kg",
        quantity: 2.0,
        par: 10.0,
        reorder: 2.0,
        est_value_per_unit: 9.0,
        measurement: "Before/after container weight (kg)",
        updated_at: "This week"
      },
      %{
        id: "ing-ascorbic-acid",
        category: "Ingredients",
        item: "Ascorbic Acid",
        location: "Store",
        unit: "kg",
        quantity: 4.5,
        par: 10.0,
        reorder: 2.0,
        est_value_per_unit: 12.0,
        measurement: "Before/after container weight (kg)",
        updated_at: "This week"
      },
      %{
        id: "ing-lemons",
        category: "Ingredients",
        item: "Lemons",
        location: "Store",
        unit: "kg",
        quantity: 35.0,
        par: 60.0,
        reorder: 20.0,
        est_value_per_unit: 1.8,
        measurement: "Fruit weight only (kg)",
        updated_at: "Today"
      },
      %{
        id: "ing-salt",
        category: "Ingredients",
        item: "Salt",
        location: "Store",
        unit: "kg",
        quantity: 25.0,
        par: 80.0,
        reorder: 15.0,
        est_value_per_unit: 0.4,
        measurement: "Before/after container weight (kg)",
        updated_at: "This week"
      },
      %{
        id: "ing-sugar",
        category: "Ingredients",
        item: "Sugar",
        location: "Store",
        unit: "kg",
        quantity: 40.0,
        par: 80.0,
        reorder: 20.0,
        est_value_per_unit: 0.9,
        measurement: "Before/after container weight (kg)",
        updated_at: "This week"
      },

      # Packaging
      %{
        id: "pkg-pouch-250",
        category: "Packaging",
        item: "Pouches (250g)",
        location: "Store",
        unit: "pcs",
        quantity: 3200.0,
        par: 5000.0,
        reorder: 1000.0,
        est_value_per_unit: 0.08,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },
      %{
        id: "pkg-pouch-500",
        category: "Packaging",
        item: "Pouches (500g)",
        location: "Store",
        unit: "pcs",
        quantity: 1800.0,
        par: 5000.0,
        reorder: 1000.0,
        est_value_per_unit: 0.10,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },
      %{
        id: "pkg-jars-300",
        category: "Packaging",
        item: "Jars (300g)",
        location: "Store",
        unit: "pcs",
        quantity: 900.0,
        par: 2000.0,
        reorder: 500.0,
        est_value_per_unit: 0.22,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },
      %{
        id: "pkg-carrier-bags",
        category: "Packaging",
        item: "Carrier Bags",
        location: "Store",
        unit: "pcs",
        quantity: 1200.0,
        par: 3000.0,
        reorder: 800.0,
        est_value_per_unit: 0.04,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },

      # Shipping
      %{
        id: "ship-box-small",
        category: "Shipping",
        item: "Shipping Boxes (Small)",
        location: "Store",
        unit: "pcs",
        quantity: 600.0,
        par: 1000.0,
        reorder: 300.0,
        est_value_per_unit: 0.25,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },
      %{
        id: "ship-box-large",
        category: "Shipping",
        item: "Shipping Boxes (Large)",
        location: "Store",
        unit: "pcs",
        quantity: 250.0,
        par: 600.0,
        reorder: 200.0,
        est_value_per_unit: 0.45,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },
      %{
        id: "ship-ice-packs",
        category: "Shipping",
        item: "Ice Packs",
        location: "Freezer",
        unit: "pcs",
        quantity: 400.0,
        par: 800.0,
        reorder: 250.0,
        est_value_per_unit: 0.15,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },

      # Labels
      %{
        id: "lbl-product-rolls",
        category: "Labels",
        item: "Product Labels",
        location: "Store",
        unit: "rolls",
        quantity: 18.0,
        par: 40.0,
        reorder: 10.0,
        est_value_per_unit: 6.0,
        measurement: "Count (rolls)",
        updated_at: "This week"
      },
      %{
        id: "lbl-batch-stickers",
        category: "Labels",
        item: "Batch Stickers",
        location: "Store",
        unit: "pcs",
        quantity: 2500.0,
        par: 5000.0,
        reorder: 1500.0,
        est_value_per_unit: 0.01,
        measurement: "Count (pcs)",
        updated_at: "This week"
      },
      %{
        id: "lbl-shipping-labels",
        category: "Labels",
        item: "Shipping Labels",
        location: "Store",
        unit: "pcs",
        quantity: 1400.0,
        par: 5000.0,
        reorder: 1500.0,
        est_value_per_unit: 0.01,
        measurement: "Count (pcs)",
        updated_at: "This week"
      }
    ]

    rows = Enum.map(rows, &enrich_row/1)

    {:ok,
     assign(socket,
       page_title: "Inventory",
       q: "",
       user_label: "User",
       unread_count: 0,
       rows: rows
     )
     |> recompute()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <TopBar.top_bar
      query={@q}
      unread_notifications={@unread_count}
      user_label={@user_label}
      on_search="topbar_search"
      on_help="topbar_help"
      on_notifications="topbar_notifications"
      on_user_menu="topbar_user_menu"
    />

    <main class="px-4 sm:px-6 lg:px-8">
      <div class="mx-auto w-full max-w-6xl py-8 sm:py-10">
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-gray-900">Inventory</h1>
          <p class="text-gray-500 mt-1">
            Current stock levels of avocados, ingredients, packaging, labels, and shipping supplies
          </p>
        </div>
        
    <!-- Top summary: low-stock callouts + totals -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <section class="rounded-2xl border border-gray-200 bg-white shadow-sm lg:col-span-2">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Totals by Category</h3>
            </div>

            <div class="p-5">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <%= for c <- @category_totals do %>
                  <div class="rounded-xl border border-gray-200 bg-white p-4">
                    <div class="flex items-center justify-between">
                      <div class="text-sm font-semibold text-gray-900">{c.category}</div>
                      <div class="text-sm text-gray-500">{fmt_money(c.value_total)}</div>
                    </div>
                    <div class="mt-2 text-sm text-gray-600">
                      <span class="font-medium text-gray-900">{c.items_count}</span>
                      items <span class="text-gray-400">•</span>
                      <span class="font-medium text-gray-900">{c.low_count}</span>
                      low/critical
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </section>

          <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Reorder Watch</h3>
            </div>

            <div class="p-5">
              <%= if Enum.empty?(@low_items) do %>
                <p class="text-sm text-gray-600">No items below reorder levels.</p>
              <% else %>
                <div class="space-y-3">
                  <%= for item <- @low_items do %>
                    <div class="flex items-start justify-between gap-3 rounded-lg bg-gray-50 p-3">
                      <div class="min-w-0">
                        <div class="flex items-center gap-2">
                          <p class="text-sm font-medium text-gray-900 truncate">
                            {item.item}
                          </p>
                          <.level_badge level={item.level} />
                        </div>
                        <p class="text-xs text-gray-500 mt-0.5">
                          {item.category} • {item.location} • Reorder at {fmt_qty(
                            item.reorder,
                            item.unit
                          )}
                        </p>
                      </div>

                      <div class="text-sm font-semibold text-gray-900 whitespace-nowrap">
                        {fmt_qty(item.quantity, item.unit)}
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <p class="mt-4 text-xs text-gray-500">
                Lemons: track fruit weight only. Other ingredients: use before/after container weights.
              </p>
            </div>
          </section>
        </div>
        
    <!-- Snapshot + Detailed table -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <!-- Snapshot -->
          <section class="rounded-2xl border border-gray-200 bg-white shadow-sm lg:col-span-1">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Inventory Snapshot</h3>
            </div>

            <div class="p-5 space-y-6">
              <%= for {cat, items} <- @grouped_snapshot do %>
                <div>
                  <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                    {cat}
                  </h4>

                  <div class="space-y-4">
                    <%= for item <- items do %>
                      <div>
                        <div class="flex justify-between text-sm mb-1">
                          <span class="text-gray-700">
                            {item.item} <span class="text-gray-400">•</span> {item.location}
                          </span>
                          <span class="font-medium">{fmt_qty(item.quantity, item.unit)}</span>
                        </div>

                        <.progress_bar
                          value={item.quantity}
                          max={max(item.par, 1.0)}
                          height="h-1.5"
                          color={level_color(item.level)}
                        />
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </section>
          
    <!-- Detailed Breakdown -->
          <section class="rounded-2xl border border-gray-200 bg-white shadow-sm lg:col-span-2">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Detailed Breakdown</h3>
            </div>

            <div class="p-5">
              <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-5 py-3 text-left font-semibold text-gray-700">Category</th>
                      <th class="px-5 py-3 text-left font-semibold text-gray-700">Item</th>
                      <th class="px-5 py-3 text-left font-semibold text-gray-700">
                        Status / Location
                      </th>
                      <th class="px-5 py-3 text-left font-semibold text-gray-700">Qty</th>
                      <th class="px-5 py-3 text-left font-semibold text-gray-700">Level</th>
                      <th class="px-5 py-3 text-left font-semibold text-gray-700">Value (Est)</th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-gray-100">
                    <%= for row <- @rows do %>
                      <tr class="hover:bg-gray-50">
                        <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{row.category}</td>
                        <td class="px-5 py-4 text-gray-900 font-medium">{row.item}</td>
                        <td class="px-5 py-4 text-gray-700">{row.location}</td>
                        <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                          {fmt_qty(row.quantity, row.unit)}
                        </td>
                        <td class="px-5 py-4 whitespace-nowrap">
                          <div class="flex items-center gap-2">
                            <.level_badge level={row.level} />
                            <span class="text-xs text-gray-500">
                              Par: {fmt_qty(row.par, row.unit)}
                            </span>
                          </div>
                          <div class="text-xs text-gray-400 mt-1">
                            {row.measurement} • Updated {row.updated_at}
                          </div>
                        </td>
                        <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                          {fmt_money(row.value_est)}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <p class="mt-4 text-xs text-gray-500">
                Inventory “level” is computed from quantity vs reorder/par. Critical & Low items should trigger purchasing and/or production planning.
              </p>
            </div>
          </section>
        </div>
      </div>
    </main>
    """
  end

  # -------------------------
  # Events (simple)
  # -------------------------

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:q, q) |> recompute()}
  end

  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  # -------------------------
  # Function components
  # -------------------------

  attr :value, :float, required: true
  attr :max, :float, default: 100.0
  attr :color, :string, default: "bg-[#2E7D32]"
  attr :height, :string, default: "h-2"

  def progress_bar(assigns) do
    maxv = if assigns.max in [0, 0.0, nil], do: 1.0, else: assigns.max * 1.0
    pct = assigns.value / maxv * 100.0
    pct = pct |> min(100.0) |> max(0.0)
    assigns = assign(assigns, pct: pct)

    ~H"""
    <div class={"w-full bg-gray-200 rounded-full overflow-hidden #{@height} shadow-inner"}>
      <div
        class={"#{@color} transition-all duration-300 ease-out h-full rounded-full shadow-sm"}
        style={"width: #{@pct}%"}
      >
      </div>
    </div>
    """
  end

  attr :level, :atom, required: true

  def level_badge(assigns) do
    {cls, label} =
      case assigns.level do
        :critical -> {"bg-red-50 text-red-700 ring-red-600/20", "Critical"}
        :low -> {"bg-yellow-50 text-yellow-700 ring-yellow-600/20", "Low"}
        _ -> {"bg-green-50 text-green-700 ring-green-600/20", "OK"}
      end

    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      {@label}
    </span>
    """
  end

  # -------------------------
  # Derived data
  # -------------------------

  defp recompute(socket) do
    q = (socket.assigns.q || "") |> String.trim() |> String.downcase()

    rows =
      socket.assigns.rows
      |> Enum.filter(fn r ->
        if q == "" do
          true
        else
          hay =
            [r.category, r.item, r.location, r.measurement]
            |> Enum.join(" ")
            |> String.downcase()

          String.contains?(hay, q)
        end
      end)

    low_items =
      rows
      |> Enum.filter(&(&1.level in [:critical, :low]))
      |> Enum.sort_by(fn r -> level_rank(r.level) end)
      |> Enum.take(5)

    category_totals =
      rows
      |> Enum.group_by(& &1.category)
      |> Enum.map(fn {cat, items} ->
        %{
          category: cat,
          items_count: length(items),
          value_total: Enum.reduce(items, 0.0, fn i, acc -> acc + i.value_est end),
          low_count: Enum.count(items, &(&1.level in [:critical, :low]))
        }
      end)
      |> Enum.sort_by(& &1.category)

    grouped_snapshot =
      rows
      |> Enum.group_by(& &1.category)
      |> Enum.map(fn {cat, items} ->
        items =
          items
          |> Enum.sort_by(fn r -> {level_rank(r.level), r.item, r.location} end)
          |> Enum.take(6)

        {cat, items}
      end)
      |> Enum.sort_by(fn {cat, _} -> cat end)

    assign(socket,
      rows: rows,
      low_items: low_items,
      category_totals: category_totals,
      grouped_snapshot: grouped_snapshot
    )
  end

  defp enrich_row(r) do
    value_est = (r.quantity || 0.0) * (r.est_value_per_unit || 0.0)
    level = compute_level(r.quantity || 0.0, r.reorder || 0.0)

    r
    |> Map.put(:value_est, value_est)
    |> Map.put(:level, level)
  end

  defp compute_level(qty, reorder) do
    cond do
      qty <= 0.0 -> :critical
      qty <= reorder * 0.75 -> :critical
      qty <= reorder -> :low
      true -> :ok
    end
  end

  defp level_rank(:critical), do: 0
  defp level_rank(:low), do: 1
  defp level_rank(_), do: 2

  defp level_color(:critical), do: "bg-red-500"
  defp level_color(:low), do: "bg-yellow-500"
  defp level_color(_), do: "bg-green-500"

  defp fmt_qty(qty, unit) when is_number(qty) and is_binary(unit) do
    qty_str =
      if unit == "kg" do
        :erlang.float_to_binary(qty * 1.0, decimals: if(qty < 10, do: 1, else: 0))
      else
        Integer.to_string(trunc(qty))
      end

    "#{qty_str} #{unit}"
  end

  defp fmt_money(amount) when is_number(amount) do
    "$" <> :erlang.float_to_binary(amount * 1.0, decimals: 2)
  end
end
