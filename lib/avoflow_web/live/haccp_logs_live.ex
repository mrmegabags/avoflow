defmodule AvoflowWeb.HACCPLogsLive do
  use AvoflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    logs = [
      %{
        id: "1",
        date: "2023-10-24",
        run_id: "PR-045",
        ccp_type: "pH",
        value: "4.3",
        status: "PASS",
        timestamp: "10:30 AM",
        corrective_action: nil
      },
      %{
        id: "2",
        date: "2023-10-24",
        run_id: "PR-045",
        ccp_type: "Sanitizer",
        value: "120 ppm",
        status: "PASS",
        timestamp: "10:35 AM",
        corrective_action: nil
      },
      %{
        id: "3",
        date: "2023-10-24",
        run_id: "PR-046",
        ccp_type: "Cooling",
        value: "85 min",
        status: "FAIL",
        timestamp: "02:15 PM",
        corrective_action: "Moved to backup fridge"
      }
    ]

    filters = %{
      date_from: "",
      date_to: "",
      status: "all",
      run_id: "",
      ccp_type: ""
    }

    socket =
      socket
      |> assign(:q, "")
      |> assign(:unread_count, 3)
      |> assign(:user_label, "QA Manager")
      |> assign(:logs, logs)
      |> assign(:filters, filters)
      |> assign(:filtered_logs, apply_filters(logs, filters))

    {:ok, socket}
  end

  @impl true
  def handle_event("topbar_search", params, socket) do
    q =
      cond do
        is_map(params) and is_binary(params["q"]) -> params["q"]
        is_map(params) and is_binary(params["query"]) -> params["query"]
        true -> socket.assigns.q
      end

    {:noreply, assign(socket, :q, q)}
  end

  @impl true
  def handle_event("filter_change", %{"filters" => incoming}, socket) do
    filters =
      socket.assigns.filters
      |> Map.merge(%{
        date_from: Map.get(incoming, "date_from", ""),
        date_to: Map.get(incoming, "date_to", ""),
        status: Map.get(incoming, "status", "all"),
        run_id: Map.get(incoming, "run_id", ""),
        ccp_type: Map.get(incoming, "ccp_type", "")
      })

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filtered_logs, apply_filters(socket.assigns.logs, filters))}
  end

  @impl true
  def handle_event("filter_apply", _params, socket) do
    # no-op; filters are applied on change
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_clear", _params, socket) do
    filters = %{date_from: "", date_to: "", status: "all", run_id: "", ccp_type: ""}

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filtered_logs, apply_filters(socket.assigns.logs, filters))}
  end

  @impl true
  def handle_event("export_csv", _params, socket) do
    # no-op per instructions
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_excel", _params, socket) do
    # no-op per instructions
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <div class="">
        <main class="">
          <div class="">
            <div class="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
              <div class="min-w-0">
                <h1 class="text-2xl font-bold text-gray-900">HACCP Logs</h1>
                <p class="text-gray-500 mt-1">Food safety compliance records</p>
              </div>

              <div class="flex flex-col space-y-2 sm:flex-row sm:space-y-0 sm:space-x-3 sm:items-center">
                <.ui_button variant="secondary" phx-click="export_csv">
                  <span class="inline-flex items-center gap-2">
                    <.download_icon />
                    <span class="whitespace-nowrap">Export CSV</span>
                  </span>
                </.ui_button>

                <.ui_button variant="secondary" phx-click="export_excel">
                  <span class="inline-flex items-center gap-2">
                    <.download_icon />
                    <span class="whitespace-nowrap">Export Excel</span>
                  </span>
                </.ui_button>
              </div>
            </div>

            <.filter_bar filters={@filters} />

            <div class="bg-white rounded-lg shadow-sm border border-gray-200">
              <.haccp_table logs={@filtered_logs} />
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end

  # -----------------------------
  # Function components
  # -----------------------------

  attr :variant, :string, default: "primary"
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_button(assigns) do
    assigns = assign(assigns, :variant_class, ui_button_variant_class(assigns.variant))

    ~H"""
    <button
      type={@type}
      class={[
        @variant_class,
        "inline-flex items-center justify-center gap-2",
        "leading-5 whitespace-nowrap",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :filters, :map, required: true

  def filter_bar(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 mb-6">
      <div class="p-4 sm:p-5">
        <form phx-change="filter_change" phx-submit="filter_apply">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3 sm:gap-4">
            <div class="flex flex-col min-w-0">
              <label class="text-sm font-medium text-gray-700">Date from</label>
              <input
                type="date"
                name="filters[date_from]"
                value={@filters.date_from}
                class="mt-1 h-10 w-full rounded-lg border border-gray-300 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-[#2E7D32] focus:ring-offset-2"
              />
            </div>

            <div class="flex flex-col min-w-0">
              <label class="text-sm font-medium text-gray-700">Date to</label>
              <input
                type="date"
                name="filters[date_to]"
                value={@filters.date_to}
                class="mt-1 h-10 w-full rounded-lg border border-gray-300 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-[#2E7D32] focus:ring-offset-2"
              />
            </div>

            <div class="flex flex-col min-w-0">
              <label class="text-sm font-medium text-gray-700">Status</label>
              <select
                name="filters[status]"
                class="mt-1 h-10 w-full rounded-lg border border-gray-300 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-[#2E7D32] focus:ring-offset-2"
              >
                <option value="all" selected={@filters.status == "all"}>All</option>
                <option value="PASS" selected={@filters.status == "PASS"}>PASS</option>
                <option value="FAIL" selected={@filters.status == "FAIL"}>FAIL</option>
              </select>
            </div>

            <div class="flex flex-col min-w-0">
              <label class="text-sm font-medium text-gray-700">Run ID</label>
              <input
                type="text"
                name="filters[run_id]"
                value={@filters.run_id}
                placeholder="e.g., PR-045"
                class="mt-1 h-10 w-full rounded-lg border border-gray-300 bg-white px-3 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#2E7D32] focus:ring-offset-2"
              />
            </div>

            <div class="flex flex-col min-w-0">
              <label class="text-sm font-medium text-gray-700">CCP Type</label>
              <input
                type="text"
                name="filters[ccp_type]"
                value={@filters.ccp_type}
                placeholder="e.g., pH"
                class="mt-1 h-10 w-full rounded-lg border border-gray-300 bg-white px-3 text-sm text-gray-900 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-[#2E7D32] focus:ring-offset-2"
              />
            </div>
          </div>

          <div class="mt-4 flex items-center justify-end gap-2 sm:gap-3 flex-wrap">
            <.ui_button variant="ghost" type="button" phx-click="filter_clear">
              Clear
            </.ui_button>

            <.ui_button variant="primary" type="submit">
              Apply
            </.ui_button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :logs, :list, required: true

  def haccp_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              Date
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              Time
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              Run ID
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              CCP Type
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              Value
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              Status
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
              Corrective Action
            </th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-200 bg-white">
          <%= if Enum.empty?(@logs) do %>
            <tr>
              <td class="px-4 py-6 text-sm text-gray-600" colspan="7">
                No logs match the current filters.
              </td>
            </tr>
          <% else %>
            <%= for log <- @logs do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 text-sm text-gray-900 whitespace-nowrap align-middle">
                  {log.date}
                </td>
                <td class="px-4 py-3 text-sm text-gray-900 whitespace-nowrap align-middle">
                  {log.timestamp}
                </td>
                <td class="px-4 py-3 text-sm text-gray-900 whitespace-nowrap align-middle">
                  {log.run_id}
                </td>
                <td class="px-4 py-3 text-sm text-gray-900 whitespace-nowrap align-middle">
                  {log.ccp_type}
                </td>
                <td class="px-4 py-3 text-sm text-gray-900 whitespace-nowrap align-middle">
                  {log.value}
                </td>
                <td class="px-4 py-3 text-sm text-gray-900 whitespace-nowrap align-middle">
                  <.status_badge status={log.status} />
                </td>
                <td class="px-4 py-3 text-sm text-gray-700 min-w-[14rem] align-middle">
                  {log.corrective_action || "-"}
                </td>
              </tr>
            <% end %>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :status, :string, required: true

  def status_badge(assigns) do
    assigns =
      assign(
        assigns,
        :classes,
        if(assigns.status == "PASS",
          do: "bg-green-100 text-green-800 ring-green-200",
          else: "bg-red-100 text-red-800 ring-red-200"
        )
      )

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset",
      @classes
    ]}>
      {@status}
    </span>
    """
  end

  def download_icon(assigns) do
    ~H"""
    <svg
      class="w-4 h-4 text-gray-700 shrink-0"
      viewBox="0 0 20 20"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        fill-rule="evenodd"
        d="M10 2a1 1 0 0 1 1 1v7.586l2.293-2.293a1 1 0 1 1 1.414 1.414l-4.004 4.004a1 1 0 0 1-1.392.022l-.022-.022L5.285 9.707a1 1 0 1 1 1.414-1.414L9 10.586V3a1 1 0 0 1 1-1Zm-6 12a1 1 0 0 1 1 1v1h10v-1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-2a1 1 0 0 1 1-1Z"
        clip-rule="evenodd"
      />
    </svg>
    """
  end

  # -----------------------------
  # Private helpers
  # -----------------------------

  defp ui_button_variant_class("primary"),
    do: "bg-[#2E7D32] text-white rounded-full h-9 px-4 text-sm"

  defp ui_button_variant_class("secondary"),
    do: "bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm"

  defp ui_button_variant_class("ghost"),
    do: "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"

  defp ui_button_variant_class(_),
    do: "bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm"

  defp apply_filters(logs, filters) do
    Enum.filter(logs, fn log ->
      status_ok =
        case filters.status do
          "all" -> true
          other -> log.status == other
        end

      date_from_ok =
        if filters.date_from in [nil, ""],
          do: true,
          else: log.date >= filters.date_from

      date_to_ok =
        if filters.date_to in [nil, ""],
          do: true,
          else: log.date <= filters.date_to

      run_ok =
        if filters.run_id in [nil, ""],
          do: true,
          else: String.contains?(String.downcase(log.run_id), String.downcase(filters.run_id))

      ccp_ok =
        if filters.ccp_type in [nil, ""],
          do: true,
          else: String.contains?(String.downcase(log.ccp_type), String.downcase(filters.ccp_type))

      status_ok and date_from_ok and date_to_ok and run_ok and ccp_ok
    end)
  end
end
