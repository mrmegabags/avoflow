defmodule AvoflowWeb.DashboardLive do
  use AvoflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    chart_data = [
      %{name: "Mon", output: 2.4},
      %{name: "Tue", output: 1.8},
      %{name: "Wed", output: 3.2},
      %{name: "Thu", output: 2.9},
      %{name: "Fri", output: 3.5},
      %{name: "Sat", output: 1.2},
      %{name: "Sun", output: 0.5}
    ]

    alerts = [
      %{
        id: 1,
        type: "warning",
        message: "Batch B-009 is ripening faster than expected",
        time: "2h ago"
      },
      %{id: 2, type: "danger", message: "Cooling unit 2 temperature deviation", time: "4h ago"},
      %{
        id: 3,
        type: "info",
        message: "New shipment from Avocorp arriving tomorrow",
        time: "5h ago"
      }
    ]

    inventory_raw = [
      %{status: "Ready", quantityKg: 45, max: 500},
      %{status: "Ripening", quantityKg: 80, max: 500},
      %{status: "Unripe", quantityKg: 120, max: 500}
    ]

    inventory_puree = [
      %{status: "Fridge", quantityKg: 12, max: 200},
      %{status: "Freezer", quantityKg: 30, max: 200}
    ]

    chart_max =
      chart_data
      |> Enum.map(& &1.output)
      |> Enum.max(fn -> 1.0 end)

    # NOTE: unread_count / q / user_label should now come from AppShell + Layout,
    # not per-page. Leave them out here to prevent UI drift.
    {:ok,
     assign(socket,
       page_title: "Dashboard",
       chart_data: chart_data,
       chart_max: chart_max,
       alerts: alerts,
       inventory_raw: inventory_raw,
       inventory_puree: inventory_puree
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Header -->
    <div class="mb-8 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p class="mt-1 text-sm text-gray-600">Overview of production and inventory status</p>
      </div>

      <div class="flex gap-3 sm:justify-end">
        <button
          type="button"
          phx-click="download_report"
          class="h-9 px-4 rounded-full text-sm bg-gray-100 text-gray-900 hover:bg-gray-200
                 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
        >
          Download Report
        </button>

        <button
          type="button"
          phx-click="new_production_run"
          class="h-9 px-4 rounded-full text-sm bg-[#2E7D32] text-white hover:brightness-95
                 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
        >
          New Production Run
        </button>
      </div>
    </div>

    <!-- KPI Tiles -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Weekly Production</p>
        <p class="mt-2 text-2xl font-semibold text-gray-900">12.4 tons</p>
        <p class="mt-4 text-sm">
          <span class="text-green-700 font-medium">▲ 12%</span>
          <span class="text-gray-500"> vs last week</span>
        </p>
      </div>

      <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Avg Yield</p>
        <p class="mt-2 text-2xl font-semibold text-gray-900">66.2%</p>
        <p class="mt-4 text-sm">
          <span class="text-green-700 font-medium">▲ 2.1%</span>
          <span class="text-gray-500"> vs target</span>
        </p>
      </div>

      <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Ready Stock</p>
        <p class="mt-2 text-2xl font-semibold text-gray-900">450 kg</p>
        <p class="mt-4 text-sm">
          <span class="text-gray-600 font-medium">• 5%</span>
          <span class="text-gray-500"> needs processing</span>
        </p>
      </div>

      <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Active Alerts</p>
        <p class="mt-2 text-2xl font-semibold text-gray-900">2</p>
        <p class="mt-4 text-sm">
          <span class="text-red-700 font-medium">▼ 1%</span>
          <span class="text-gray-500"> new today</span>
        </p>
      </div>
    </div>

    <!-- Chart + Inventory -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
      <!-- Chart -->
      <section class="lg:col-span-2 rounded-2xl border border-gray-200 bg-white shadow-sm">
        <div class="px-5 pt-5">
          <h3 class="text-sm font-semibold text-gray-900">Production Output (Last 7 Days)</h3>
        </div>

        <div class="p-5">
          <div class="h-72 w-full">
            <div class="h-full w-full grid grid-cols-7 gap-4 items-end">
              <%= for p <- @chart_data do %>
                <div class="flex flex-col items-center justify-end gap-2 h-full">
                  <div class="w-full flex items-end justify-center h-full">
                    <div
                      class="w-10 rounded-t-md bg-[#2E7D32]"
                      style={"height: #{bar_height_pct(p.output, @chart_max)}%;"}
                      title={"#{p.name}: #{p.output}"}
                    >
                    </div>
                  </div>
                  <div class="text-xs text-gray-500">{p.name}</div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Inventory -->
      <section class="lg:col-span-1 rounded-2xl border border-gray-200 bg-white shadow-sm">
        <div class="px-5 pt-5">
          <h3 class="text-sm font-semibold text-gray-900">Inventory Snapshot</h3>
        </div>

        <div class="p-5 space-y-6">
          <div>
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4">
              Raw Avocados
            </h4>

            <div class="space-y-4">
              <%= for item <- @inventory_raw do %>
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="text-gray-700">{item.status}</span>
                    <span class="font-medium text-gray-900">{item.quantityKg} kg</span>
                  </div>

                  <div class="h-1.5 w-full rounded-full bg-gray-100 overflow-hidden">
                    <div
                      class={"h-full rounded-full #{raw_color(item.status)}"}
                      style={"width: #{progress_pct(item.quantityKg, item.max)}%;"}
                    >
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <div class="pt-4 border-t border-gray-100">
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-4">
              Processed Purée
            </h4>

            <div class="space-y-4">
              <%= for item <- @inventory_puree do %>
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span class="text-gray-700">{item.status}</span>
                    <span class="font-medium text-gray-900">{item.quantityKg} kg</span>
                  </div>

                  <div class="h-1.5 w-full rounded-full bg-gray-100 overflow-hidden">
                    <div
                      class="h-full rounded-full bg-blue-500"
                      style={"width: #{progress_pct(item.quantityKg, item.max)}%;"}
                    >
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </section>
    </div>

    <!-- Alerts -->
    <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
      <div class="flex items-center justify-between px-5 pt-5">
        <h3 class="text-sm font-semibold text-gray-900">Recent Alerts</h3>

        <button
          type="button"
          phx-click="alerts_view_all"
          class="text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm
                 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
        >
          View All
        </button>
      </div>

      <div class="p-5 space-y-4">
        <%= for a <- @alerts do %>
          <div class="flex items-start p-3 rounded-lg bg-gray-50 hover:bg-gray-100 transition-colors">
            <span class={"mt-0.5 mr-3 h-2.5 w-2.5 rounded-full #{alert_dot(a.type)}"}></span>

            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-gray-900">{a.message}</p>
              <p class="text-xs text-gray-500 mt-1">{a.time}</p>
            </div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  @impl true
  def handle_event("download_report", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("new_production_run", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("alerts_view_all", _params, socket), do: {:noreply, socket}

  # Helpers
  defp bar_height_pct(value, max_value) do
    maxv = if max_value in [0, 0.0], do: 1.0, else: max_value * 1.0
    pct = value * 1.0 / maxv * 100.0
    pct |> min(100.0) |> max(2.0) |> Float.round(2)
  end

  defp progress_pct(value, max_value) do
    maxv = if max_value in [0, 0.0, nil], do: 1.0, else: max_value * 1.0
    pct = value * 1.0 / maxv * 100.0
    pct |> min(100.0) |> max(0.0) |> Float.round(2)
  end

  defp raw_color("Ready"), do: "bg-green-500"
  defp raw_color("Ripening"), do: "bg-yellow-500"
  defp raw_color(_), do: "bg-gray-300"

  defp alert_dot("danger"), do: "bg-red-500"
  defp alert_dot("warning"), do: "bg-yellow-500"
  defp alert_dot(_), do: "bg-blue-500"
end
