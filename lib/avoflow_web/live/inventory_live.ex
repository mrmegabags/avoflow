defmodule AvoflowWeb.InventoryLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar
  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    all_rows =
      [
        # Avocados
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

        # Ingredients (lemons = fruit weight only; others can be before/after container weights)
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
      |> Enum.map(&enrich_row/1)

    categories =
      ["All"]
      |> Enum.concat(all_rows |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort())

    locations =
      ["All"]
      |> Enum.concat(all_rows |> Enum.map(& &1.location) |> Enum.uniq() |> Enum.sort())

    all_movements = seed_movements()

    history_items =
      ["All"]
      |> Enum.concat(
        Enum.map(all_rows, fn r -> "#{r.id}::#{r.category} — #{r.item} • #{r.location}" end)
      )

    {:ok,
     socket
     |> assign(
       page_title: "Inventory",
       q: "",
       unread_count: 1,
       all_rows: all_rows,
       rows: [],
       categories: categories,
       locations: locations,
       category_filter: "All",
       level_filter: "All",
       location_filter: "All",
       # movements
       all_movements: all_movements,
       filtered_movements: [],
       history_items: history_items,
       history_item_filter: "All",
       history_limit: 50
     )
     |> recompute()}
  end

  @impl true
  def render(assigns) do
    q = assigns.q || ""

    export_params =
      %{
        "item" => assigns.history_item_filter,
        "q" => q,
        "category" => assigns.category_filter,
        "level" => assigns.level_filter,
        "location" => assigns.location_filter
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    csv_href = "/inventory/movements.csv?" <> URI.encode_query(export_params)
    xls_href = "/inventory/movements.xls?" <> URI.encode_query(export_params)
    pdf_href = "/inventory/movements.pdf?" <> URI.encode_query(export_params)

    assigns =
      assigns
      |> assign(:csv_href, csv_href)
      |> assign(:xls_href, xls_href)
      |> assign(:pdf_href, pdf_href)

    ~H"""
    <main class="">
      <div class="">
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-gray-900">Inventory</h1>
          <p class="text-gray-500 mt-1">
            Current stock levels of avocados, ingredients, packaging, labels, and shipping supplies
          </p>
          
    <!-- Global filters (these now drive totals + snapshot + detailed) -->
          <form
            phx-change="filters_change"
            class="mt-4 flex flex-col sm:flex-row gap-2 sm:items-center"
          >
            <div class="flex flex-wrap gap-2">
              <select
                name="filters[category]"
                class="h-9 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                       focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:bg-white"
              >
                <%= for c <- @categories do %>
                  <option value={c} selected={@category_filter == c}>{c}</option>
                <% end %>
              </select>

              <select
                name="filters[level]"
                class="h-9 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                       focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:bg-white"
              >
                <%= for l <- ["All", "OK", "Low", "Critical"] do %>
                  <option value={l} selected={@level_filter == l}>{l}</option>
                <% end %>
              </select>

              <select
                name="filters[location]"
                class="h-9 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                       focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:bg-white"
              >
                <%= for loc <- @locations do %>
                  <option value={loc} selected={@location_filter == loc}>{loc}</option>
                <% end %>
              </select>
            </div>

            <p class="text-xs text-gray-500 sm:ml-auto">
              Showing {length(@rows)} item(s)
            </p>
          </form>
        </div>
        
    <!-- Top summary (now respects filters) -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <section class="rounded-2xl border border-gray-200 bg-white shadow-sm lg:col-span-2">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Totals by Category</h3>
            </div>

            <div class="p-5">
              <%= if Enum.empty?(@category_totals) do %>
                <p class="text-sm text-gray-600">No items match the current filters.</p>
              <% else %>
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
              <% end %>
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
                          <p class="text-sm font-medium text-gray-900 truncate">{item.item}</p>
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
        
    <!-- Snapshot + Detailed (now respects filters) -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <section class="rounded-2xl border border-gray-200 bg-white shadow-sm lg:col-span-1">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Inventory Snapshot</h3>
            </div>

            <div class="p-5 space-y-6">
              <%= if Enum.empty?(@grouped_snapshot) do %>
                <p class="text-sm text-gray-600">No items match the current filters.</p>
              <% else %>
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
              <% end %>
            </div>
          </section>

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

                    <%= if Enum.empty?(@rows) do %>
                      <tr>
                        <td colspan="6" class="px-5 py-8 text-center text-sm text-gray-500">
                          No items match the current filters.
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
        
    <!-- Movement History + Export (controller endpoints) -->
        <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
          <div class="px-5 pt-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div>
              <h3 class="text-sm font-semibold text-gray-900">Movement History</h3>
              <p class="text-xs text-gray-500 mt-1">
                Track changes to quantities over time (usage, receipts, transfers). Export as CSV/Excel/PDF.
              </p>
            </div>

            <div class="flex flex-col sm:flex-row gap-2 sm:items-center">
              <form phx-change="history_filter_change">
                <select
                  name="item"
                  class="h-9 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                         focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:bg-white"
                >
                  <%= for opt <- @history_items do %>
                    <% {id, label} = parse_history_item_option(opt) %>
                    <option value={id} selected={@history_item_filter == id}>{label}</option>
                  <% end %>
                </select>
              </form>

              <div class="flex gap-2">
                <a
                  href={@csv_href}
                  class="inline-flex items-center justify-center h-9 px-4 rounded-full text-sm font-medium
                         bg-gray-100 text-gray-900 hover:bg-gray-200
                         focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
                >
                  Export CSV
                </a>

                <a
                  href={@xls_href}
                  class="inline-flex items-center justify-center h-9 px-4 rounded-full text-sm font-medium
                         bg-gray-100 text-gray-900 hover:bg-gray-200
                         focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
                >
                  Export Excel
                </a>

                <a
                  href={@pdf_href}
                  class="inline-flex items-center justify-center h-9 px-4 rounded-full text-sm font-medium
                         bg-gray-100 text-gray-900 hover:bg-gray-200
                         focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
                >
                  Export PDF
                </a>
              </div>
            </div>
          </div>

          <div class="p-5">
            <div class="overflow-x-auto">
              <table class="min-w-full text-sm">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">Time</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">Category</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">Item</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">From → To</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">Change</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">Qty After</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">Reason</th>
                    <th class="px-5 py-3 text-left font-semibold text-gray-700">User</th>
                  </tr>
                </thead>

                <tbody class="divide-y divide-gray-100">
                  <%= for m <- @filtered_movements do %>
                    <tr class="hover:bg-gray-50">
                      <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{m.at}</td>
                      <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{m.category}</td>
                      <td class="px-5 py-4 text-gray-900 font-medium">{m.item}</td>
                      <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{m.from} → {m.to}</td>
                      <td class="px-5 py-4 whitespace-nowrap">
                        <span class={delta_class(m.delta)}>
                          {fmt_signed(m.delta)} {m.unit}
                        </span>
                      </td>
                      <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                        {fmt_qty(m.qty_after, m.unit)}
                      </td>
                      <td class="px-5 py-4 text-gray-700">{m.reason}</td>
                      <td class="px-5 py-4 text-gray-700 whitespace-nowrap">{m.user}</td>
                    </tr>
                  <% end %>

                  <%= if Enum.empty?(@filtered_movements) do %>
                    <tr>
                      <td colspan="8" class="px-5 py-8 text-center text-sm text-gray-500">
                        No movement records found for the selected filters.
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
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
  def handle_event("topbar_search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:q, q) |> recompute()}
  end

  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  def handle_event("filters_change", %{"filters" => filters}, socket) do
    {:noreply,
     socket
     |> assign(
       category_filter: Map.get(filters, "category", "All"),
       level_filter: Map.get(filters, "level", "All"),
       location_filter: Map.get(filters, "location", "All")
     )
     |> recompute()}
  end

  def handle_event("history_filter_change", %{"item" => item_id}, socket) do
    {:noreply, socket |> assign(:history_item_filter, item_id) |> recompute()}
  end

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
  # Derived data (now driven by the SAME filters)
  # -------------------------

  defp recompute(socket) do
    q = (socket.assigns.q || "") |> String.trim() |> String.downcase()
    cat = socket.assigns.category_filter || "All"
    lvl = socket.assigns.level_filter || "All"
    loc = socket.assigns.location_filter || "All"

    rows =
      socket.assigns.all_rows
      |> Enum.filter(fn r -> cat == "All" or r.category == cat end)
      |> Enum.filter(fn r -> loc == "All" or r.location == loc end)
      |> Enum.filter(fn r -> level_match?(r.level, lvl) end)
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
      |> Enum.map(fn {category, items} ->
        %{
          category: category,
          items_count: length(items),
          value_total: Enum.reduce(items, 0.0, fn i, acc -> acc + i.value_est end),
          low_count: Enum.count(items, &(&1.level in [:critical, :low]))
        }
      end)
      |> Enum.sort_by(& &1.category)

    grouped_snapshot =
      rows
      |> Enum.group_by(& &1.category)
      |> Enum.map(fn {category, items} ->
        items =
          items
          |> Enum.sort_by(fn r -> {level_rank(r.level), r.item, r.location} end)
          |> Enum.take(6)

        {category, items}
      end)
      |> Enum.sort_by(fn {category, _} -> category end)

    filtered_movements =
      socket.assigns.all_movements
      |> Enum.filter(fn m ->
        socket.assigns.history_item_filter == "All" or
          m.item_id == socket.assigns.history_item_filter
      end)
      |> Enum.filter(fn m ->
        # Also respect the same global filters for consistency
        (cat == "All" or m.category == cat) and
          (loc == "All" or m.to == loc or m.from == loc) and
          level_match?(movement_level(m), lvl)
      end)
      |> Enum.filter(fn m ->
        if q == "" do
          true
        else
          hay =
            [m.at, m.category, m.item, m.from, m.to, m.reason, m.user]
            |> Enum.join(" ")
            |> String.downcase()

          String.contains?(hay, q)
        end
      end)
      |> Enum.take(socket.assigns.history_limit || 50)

    assign(socket,
      rows: rows,
      low_items: low_items,
      category_totals: category_totals,
      grouped_snapshot: grouped_snapshot,
      filtered_movements: filtered_movements
    )
  end

  defp level_match?(_level_atom, "All"), do: true
  defp level_match?(:ok, "OK"), do: true
  defp level_match?(:low, "Low"), do: true
  defp level_match?(:critical, "Critical"), do: true
  defp level_match?(_level_atom, _), do: false

  # Movement rows don’t have reorder/par; we keep level filtering simple:
  # - negative deltas treated as :low (consumption), else :ok
  # This is only for the movement table filter consistency.
  defp movement_level(%{delta: d}) when is_number(d) and d < 0, do: :low
  defp movement_level(_), do: :ok

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

  # -------------------------
  # History helpers
  # -------------------------

  defp parse_history_item_option("All"), do: {"All", "All items"}

  defp parse_history_item_option(opt) do
    case String.split(opt, "::", parts: 2) do
      [id, label] -> {id, label}
      _ -> {opt, opt}
    end
  end

  defp fmt_signed(n) when is_number(n) do
    s = :erlang.float_to_binary(n * 1.0, decimals: 1)
    if n >= 0, do: "+" <> s, else: s
  end

  defp delta_class(delta) when is_number(delta) do
    cond do
      delta < 0 -> "text-red-700 font-medium"
      delta > 0 -> "text-green-700 font-medium"
      true -> "text-gray-700"
    end
  end

  defp seed_movements do
    [
      %{
        at: "2023-10-24 08:00",
        item_id: "avo-raw-ready",
        category: "Avocados",
        item: "Raw",
        from: "Receiving",
        to: "Ready",
        delta: 45.0,
        unit: "kg",
        qty_after: 45.0,
        reason: "Batch intake",
        user: "John Doe"
      },
      %{
        at: "2023-10-25 09:00",
        item_id: "avo-raw-ripening",
        category: "Avocados",
        item: "Raw",
        from: "Unripe",
        to: "Ripening",
        delta: 25.0,
        unit: "kg",
        qty_after: 80.0,
        reason: "Ripening room transfer",
        user: "Jane Smith"
      },
      %{
        at: "2023-10-26 10:30",
        item_id: "ing-olive-oil",
        category: "Ingredients",
        item: "Olive Oil",
        from: "Store",
        to: "Production",
        delta: -2.0,
        unit: "kg",
        qty_after: 18.0,
        reason: "Production use",
        user: "Jane Smith"
      },
      %{
        at: "2023-10-27 15:10",
        item_id: "lbl-batch-stickers",
        category: "Labels",
        item: "Batch Stickers",
        from: "Store",
        to: "Packing",
        delta: -300.0,
        unit: "pcs",
        qty_after: 2500.0,
        reason: "Packing run",
        user: "John Doe"
      }
    ]
  end
end

defmodule AvoflowWeb.InventoryExportController do
  use AvoflowWeb, :controller

  def movements_csv(conn, params) do
    movements = filtered(params)
    csv = build_movements_csv(movements)

    Phoenix.Controller.send_download(conn, {:binary, csv},
      filename: "inventory_movements.csv",
      content_type: "text/csv"
    )
  end

  def movements_xls(conn, params) do
    movements = filtered(params)
    xls = build_movements_xls_html(movements)

    Phoenix.Controller.send_download(conn, {:binary, xls},
      filename: "inventory_movements.xls",
      content_type: "application/vnd.ms-excel"
    )
  end

  def movements_pdf(conn, params) do
    movements = filtered(params)
    pdf = build_movements_pdf(movements)

    Phoenix.Controller.send_download(conn, {:binary, pdf},
      filename: "inventory_movements.pdf",
      content_type: "application/pdf"
    )
  end

  # --- simple mock filtering (matches the LiveView) ---

  defp filtered(params) do
    item = Map.get(params, "item", "All")
    q = params |> Map.get("q", "") |> to_string() |> String.trim() |> String.downcase()
    cat = Map.get(params, "category", "All")
    lvl = Map.get(params, "level", "All")
    loc = Map.get(params, "location", "All")

    seed_movements()
    |> Enum.filter(fn m -> item == "All" or m.item_id == item end)
    |> Enum.filter(fn m -> cat == "All" or m.category == cat end)
    |> Enum.filter(fn m -> loc == "All" or m.to == loc or m.from == loc end)
    |> Enum.filter(fn m -> level_match?(movement_level(m), lvl) end)
    |> Enum.filter(fn m ->
      if q == "" do
        true
      else
        hay =
          [m.at, m.category, m.item, m.from, m.to, m.reason, m.user]
          |> Enum.join(" ")
          |> String.downcase()

        String.contains?(hay, q)
      end
    end)
  end

  defp movement_level(%{delta: d}) when is_number(d) and d < 0, do: :low
  defp movement_level(_), do: :ok

  defp level_match?(_level_atom, "All"), do: true
  defp level_match?(:ok, "OK"), do: true
  defp level_match?(:low, "Low"), do: true
  defp level_match?(:critical, "Critical"), do: true
  defp level_match?(_level_atom, _), do: false

  defp seed_movements do
    [
      %{
        at: "2023-10-24 08:00",
        item_id: "avo-raw-ready",
        category: "Avocados",
        item: "Raw",
        from: "Receiving",
        to: "Ready",
        delta: 45.0,
        unit: "kg",
        qty_after: 45.0,
        reason: "Batch intake",
        user: "John Doe"
      },
      %{
        at: "2023-10-25 09:00",
        item_id: "avo-raw-ripening",
        category: "Avocados",
        item: "Raw",
        from: "Unripe",
        to: "Ripening",
        delta: 25.0,
        unit: "kg",
        qty_after: 80.0,
        reason: "Ripening room transfer",
        user: "Jane Smith"
      },
      %{
        at: "2023-10-26 10:30",
        item_id: "ing-olive-oil",
        category: "Ingredients",
        item: "Olive Oil",
        from: "Store",
        to: "Production",
        delta: -2.0,
        unit: "kg",
        qty_after: 18.0,
        reason: "Production use",
        user: "Jane Smith"
      },
      %{
        at: "2023-10-27 15:10",
        item_id: "lbl-batch-stickers",
        category: "Labels",
        item: "Batch Stickers",
        from: "Store",
        to: "Packing",
        delta: -300.0,
        unit: "pcs",
        qty_after: 2500.0,
        reason: "Packing run",
        user: "John Doe"
      }
    ]
  end

  # --- CSV / Excel / PDF builders (simple + dependency-free) ---

  defp build_movements_csv(movements) do
    header =
      ["Time", "Category", "Item", "From", "To", "Change", "Unit", "Qty After", "Reason", "User"]
      |> Enum.map(&csv_escape/1)
      |> Enum.join(",")

    rows =
      Enum.map(movements, fn m ->
        [
          m.at,
          m.category,
          m.item,
          m.from,
          m.to,
          m.delta,
          m.unit,
          m.qty_after,
          m.reason,
          m.user
        ]
        |> Enum.map(&csv_escape/1)
        |> Enum.join(",")
      end)

    Enum.join([header | rows], "\n")
  end

  defp csv_escape(nil), do: ~s("")

  defp csv_escape(v) when is_number(v),
    do: csv_escape(:erlang.float_to_binary(v * 1.0, decimals: 2))

  defp csv_escape(v) do
    s = to_string(v)
    s = String.replace(s, ~s("), ~s(""))
    ~s("#{s}")
  end

  # Excel export: HTML table saved as .xls (opens in Excel)
  defp build_movements_xls_html(movements) do
    rows_html =
      movements
      |> Enum.map(fn m ->
        """
        <tr>
          <td>#{html(m.at)}</td>
          <td>#{html(m.category)}</td>
          <td>#{html(m.item)}</td>
          <td>#{html(m.from)}</td>
          <td>#{html(m.to)}</td>
          <td>#{html(m.delta)}</td>
          <td>#{html(m.unit)}</td>
          <td>#{html(m.qty_after)}</td>
          <td>#{html(m.reason)}</td>
          <td>#{html(m.user)}</td>
        </tr>
        """
      end)
      |> Enum.join("\n")

    """
    <html>
      <head><meta charset="utf-8" /></head>
      <body>
        <table border="1" cellspacing="0" cellpadding="4">
          <thead>
            <tr>
              <th>Time</th><th>Category</th><th>Item</th><th>From</th><th>To</th>
              <th>Change</th><th>Unit</th><th>Qty After</th><th>Reason</th><th>User</th>
            </tr>
          </thead>
          <tbody>
            #{rows_html}
          </tbody>
        </table>
      </body>
    </html>
    """
  end

  defp html(nil), do: ""

  defp html(v) do
    v
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace(~s("), "&quot;")
  end

  # Minimal PDF export (text-only; dependency-free)
  defp build_movements_pdf(movements) do
    lines =
      ["Inventory Movements"] ++
        Enum.map(movements, fn m ->
          "#{m.at} | #{m.category} | #{m.item} | #{m.from}->#{m.to} | #{m.delta} #{m.unit} | after #{m.qty_after} | #{m.user}"
        end)

    stream = pdf_text_stream(lines)
    pdf_build_single_page(stream)
  end

  defp pdf_text_stream(lines) do
    font_size = 10
    start_x = 50
    start_y = 780
    leading = 14

    encoded =
      lines
      |> Enum.take(45)
      |> Enum.map(&pdf_escape/1)

    content =
      [
        "BT\n",
        "/F1 #{font_size} Tf\n",
        "#{leading} TL\n",
        "#{start_x} #{start_y} Td\n"
      ] ++
        Enum.map(encoded, fn line -> "(#{line}) Tj\nT*\n" end) ++
        ["ET\n"]

    IO.iodata_to_binary(content)
  end

  defp pdf_escape(s) do
    s
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  defp pdf_build_single_page(stream) do
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n",
      "4 0 obj\n<< /Length #{byte_size(stream)} >>\nstream\n#{stream}\nendstream\nendobj\n",
      "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
    ]

    header = "%PDF-1.4\n"
    {body, offsets} = pdf_objects_with_offsets(header, objects)
    xref_start = byte_size(header) + byte_size(body)

    xref =
      ["xref\n0 6\n", "0000000000 65535 f \n"] ++
        Enum.map(offsets, fn off ->
          :io_lib.format("~10..0B 00000 n \n", [off]) |> IO.iodata_to_binary()
        end)

    trailer = "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref_start}\n%%EOF\n"
    IO.iodata_to_binary([header, body, xref, trailer])
  end

  defp pdf_objects_with_offsets(header, objects) do
    {bin, offsets, _pos} =
      Enum.reduce(objects, {"", [], byte_size(header)}, fn obj, {acc, offs, pos} ->
        obj_bin = IO.iodata_to_binary(obj)
        {acc <> obj_bin, offs ++ [pos], pos + byte_size(obj_bin)}
      end)

    {bin, offsets}
  end
end
