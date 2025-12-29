defmodule AvoflowWeb.HoldsQuarantineLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar

  @page_size 4

  @impl true
  def mount(_params, _session, socket) do
    active_holds = [
      %{
        id: "HOLD-001",
        type: "micro",
        lots: ["LOT-087"],
        units: 45,
        reason: "Positive micro test result on sample",
        created_by: "QA Team",
        created_at: "2024-12-15 11:00",
        status: "active",
        attachments: ["lab_report_001.pdf"]
      },
      %{
        id: "HOLD-002",
        type: "temperature",
        lots: ["LOT-085"],
        units: 12,
        reason: "Temperature excursion detected during transport",
        created_by: "QA Team",
        created_at: "2024-12-14 16:30",
        status: "active",
        attachments: ["temp_log_001.pdf"]
      },
      %{
        id: "HOLD-003",
        type: "label",
        lots: ["LOT-083"],
        units: 8,
        reason: "Incorrect expiry date printed on labels",
        created_by: "QA Team",
        created_at: "2024-12-14 09:15",
        status: "active",
        attachments: []
      }
    ]

    released_holds = [
      %{
        id: "HOLD-004",
        type: "qa",
        lots: ["LOT-086"],
        units: 20,
        reason: "Routine QA hold for sample testing",
        created_by: "QA Team",
        created_at: "2024-12-13 10:00",
        released_by: "S.Kim",
        released_at: "2024-12-13 14:30",
        hold_duration: "4.5 hours",
        disposition: "released",
        resolution_notes: "All tests passed. Released for distribution.",
        status: "released"
      },
      %{
        id: "HOLD-005",
        type: "temperature",
        lots: ["LOT-084"],
        units: 15,
        reason: "Brief temperature spike during power outage",
        created_by: "QA Team",
        created_at: "2024-12-12 08:00",
        released_by: "S.Kim",
        released_at: "2024-12-12 16:00",
        hold_duration: "8 hours",
        disposition: "released",
        resolution_notes:
          "Temperature logs reviewed. Product remained within safe range. Released.",
        status: "released"
      },
      %{
        id: "HOLD-006",
        type: "label",
        lots: ["LOT-082"],
        units: 30,
        reason: "Missing allergen warning on labels",
        created_by: "QA Team",
        created_at: "2024-12-11 09:00",
        released_by: "S.Kim",
        released_at: "2024-12-11 15:00",
        hold_duration: "6 hours",
        disposition: "scrapped",
        resolution_notes: "Labels could not be corrected. Units scrapped per SOP.",
        status: "released"
      },
      %{
        id: "HOLD-007",
        type: "micro",
        lots: ["LOT-081"],
        units: 50,
        reason: "Suspected contamination during packing",
        created_by: "QA Team",
        created_at: "2024-12-10 11:00",
        released_by: "S.Kim",
        released_at: "2024-12-12 09:00",
        hold_duration: "46 hours",
        disposition: "scrapped",
        resolution_notes: "Positive micro test confirmed. All units destroyed.",
        status: "released"
      }
    ]

    socket =
      socket
      |> assign(:q, "")
      |> assign(:unread_count, 2)
      |> assign(:user_label, "S.Kim")
      |> assign(:active_tab, "active")
      |> assign(:toast, nil)
      |> assign(:active_holds, active_holds)
      |> assign(:released_holds, released_holds)
      |> assign(:selected_hold_id, nil)
      |> assign(:resolution_notes, "")
      |> assign(:released_search, "")
      |> assign(:released_disposition, "all")
      |> assign(:released_range, "7")
      |> assign(:released_page, 1)
      |> assign(:new_hold, %{type: "", lots: "", reason: "", notes: ""})

    {:ok, socket}
  end

  # --------------------
  # TopBar no-op handlers
  # --------------------

  @impl true
  def handle_event("topbar_search", params, socket) do
    q =
      Map.get(params, "q") ||
        Map.get(params, "query") ||
        Map.get(params, "search") ||
        ""

    {:noreply, assign(socket, :q, q)}
  end

  @impl true
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}

  # --------------------
  # Generic UI
  # --------------------

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    tab = if tab in ["active", "released", "new"], do: tab, else: "active"
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("clear_toast", _params, socket), do: {:noreply, assign(socket, :toast, nil)}

  # --------------------
  # Drawer
  # --------------------

  @impl true
  def handle_event("open_hold", %{"id" => id}, socket) do
    if Enum.any?(socket.assigns.active_holds, &(&1.id == id)) do
      {:noreply, socket |> assign(:selected_hold_id, id) |> assign(:resolution_notes, "")}
    else
      {:noreply, toast(socket, :info, "Hold not found (it may have been released).")}
    end
  end

  @impl true
  def handle_event("close_hold", _params, socket) do
    {:noreply, socket |> assign(:selected_hold_id, nil) |> assign(:resolution_notes, "")}
  end

  @impl true
  def handle_event("resolution_change", %{"resolution_notes" => notes}, socket) do
    {:noreply, assign(socket, :resolution_notes, notes || "")}
  end

  @impl true
  def handle_event("download_attachment", %{"file" => file}, socket) do
    {:noreply, toast(socket, :info, "Download requested: #{file} (mock).")}
  end

  @impl true
  def handle_event("release_hold", %{"id" => id}, socket) do
    resolve_hold(socket, id, "released")
  end

  @impl true
  def handle_event("scrap_hold", %{"id" => id}, socket) do
    resolve_hold(socket, id, "scrapped")
  end

  defp resolve_hold(socket, id, disposition) when disposition in ["released", "scrapped"] do
    case Enum.split_with(socket.assigns.active_holds, &(&1.id != id)) do
      {kept, [hold | _rest]} ->
        released_at = now_string()
        hold_duration = duration_string(hold.created_at, released_at)

        resolution_notes =
          socket.assigns.resolution_notes
          |> to_string()
          |> String.trim()
          |> case do
            "" ->
              if disposition == "released" do
                "Released by #{socket.assigns.user_label}."
              else
                "Scrapped per SOP. Authorized by #{socket.assigns.user_label}."
              end

            notes ->
              notes
          end

        released =
          %{
            id: hold.id,
            type: hold.type,
            lots: hold.lots,
            units: hold.units,
            reason: hold.reason,
            created_by: hold.created_by,
            created_at: hold.created_at,
            released_by: socket.assigns.user_label,
            released_at: released_at,
            hold_duration: hold_duration,
            disposition: disposition,
            resolution_notes: resolution_notes,
            status: "released"
          }

        socket =
          socket
          |> assign(:active_holds, kept)
          |> assign(:released_holds, [released | socket.assigns.released_holds])
          |> assign(:selected_hold_id, nil)
          |> assign(:resolution_notes, "")
          |> assign(:active_tab, "released")
          |> assign(:released_page, 1)
          |> toast(
            :success,
            "#{hold.id} #{if disposition == "released", do: "released", else: "scrapped"}."
          )

        {:noreply, socket}

      {_kept, []} ->
        {:noreply, toast(socket, :info, "Hold not found (it may have been released already).")}
    end
  end

  # --------------------
  # Released tab filters / paging
  # --------------------

  @impl true
  def handle_event("released_search", %{"released_search" => val}, socket) do
    {:noreply, socket |> assign(:released_search, val || "") |> assign(:released_page, 1)}
  end

  @impl true
  def handle_event("released_disposition", %{"released_disposition" => val}, socket) do
    val = if val in ["all", "released", "scrapped"], do: val, else: "all"
    {:noreply, socket |> assign(:released_disposition, val) |> assign(:released_page, 1)}
  end

  @impl true
  def handle_event("released_range", %{"released_range" => val}, socket) do
    val = if val in ["7", "30", "90"], do: val, else: "7"
    {:noreply, socket |> assign(:released_range, val) |> assign(:released_page, 1)}
  end

  @impl true
  def handle_event("released_prev", _params, socket) do
    {:noreply, update(socket, :released_page, fn p -> max(p - 1, 1) end)}
  end

  @impl true
  def handle_event("released_next", _params, socket) do
    {:noreply, update(socket, :released_page, &(&1 + 1))}
  end

  # --------------------
  # New Hold
  # --------------------

  @impl true
  def handle_event("new_hold_change", %{"new_hold" => attrs}, socket) when is_map(attrs) do
    new_hold =
      socket.assigns.new_hold
      |> Map.merge(%{
        type: Map.get(attrs, "type", socket.assigns.new_hold.type),
        lots: Map.get(attrs, "lots", socket.assigns.new_hold.lots),
        reason: Map.get(attrs, "reason", socket.assigns.new_hold.reason),
        notes: Map.get(attrs, "notes", socket.assigns.new_hold.notes)
      })

    {:noreply, assign(socket, :new_hold, new_hold)}
  end

  @impl true
  def handle_event("new_hold_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:new_hold, %{type: "", lots: "", reason: "", notes: ""})
     |> assign(:active_tab, "active")
     |> toast(:info, "Cancelled.")}
  end

  @impl true
  def handle_event("new_hold_upload_stub", _params, socket) do
    {:noreply, toast(socket, :info, "Uploads are stubbed in this mock page.")}
  end

  @impl true
  def handle_event("new_hold_create", _params, socket) do
    nh = socket.assigns.new_hold

    type = nh.type |> to_string() |> String.trim()
    lots_str = nh.lots |> to_string() |> String.trim()
    reason = nh.reason |> to_string() |> String.trim()
    notes = nh.notes |> to_string() |> String.trim()

    cond do
      type == "" ->
        {:noreply, toast(socket, :info, "Select a hold type.")}

      lots_str == "" ->
        {:noreply, toast(socket, :info, "Enter at least one lot.")}

      reason == "" ->
        {:noreply, toast(socket, :info, "Reason is required.")}

      true ->
        lots =
          lots_str
          |> String.split([",", " "], trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        id = next_hold_id(socket.assigns.active_holds, socket.assigns.released_holds)

        hold = %{
          id: id,
          type: type,
          lots: lots,
          units: estimate_units_from_lots(lots),
          reason: reason,
          created_by: "QA Team",
          created_at: now_string(),
          status: "active",
          attachments: []
        }

        socket =
          socket
          |> assign(:active_holds, [hold | socket.assigns.active_holds])
          |> assign(:new_hold, %{type: "", lots: "", reason: "", notes: ""})
          |> assign(:active_tab, "active")
          |> toast(:success, "Created #{id}.#{if notes != "", do: " Notes saved.", else: ""}")

        {:noreply, socket}
    end
  end

  # --------------------
  # Render
  # --------------------

  @impl true
  def render(assigns) do
    active_count = length(assigns.active_holds)
    units_on_hold = Enum.reduce(assigns.active_holds, 0, fn h, acc -> acc + (h.units || 0) end)

    released_filtered =
      filter_released(
        assigns.released_holds,
        assigns.released_search,
        assigns.released_disposition
      )

    released_total = length(released_filtered)

    released_page = max(assigns.released_page, 1)
    {released_page_items, page_info} = paginate(released_filtered, released_page, @page_size)

    selected_hold = Enum.find(assigns.active_holds, &(&1.id == assigns.selected_hold_id))

    released_7d = length(assigns.released_holds)
    avg_days = avg_hold_days(assigns.released_holds)

    assigns =
      assigns
      |> assign(:active_count, active_count)
      |> assign(:units_on_hold, units_on_hold)
      |> assign(:released_7d, released_7d)
      |> assign(:avg_days, avg_days)
      |> assign(:released_total, released_total)
      |> assign(:released_page_items, released_page_items)
      |> assign(:page_info, page_info)
      |> assign(:released_page, page_info.page)
      |> assign(:selected_hold, selected_hold)

    ~H"""
    <div>
      <div class="">
        <main class="">
          <div class="">
            <%= if @toast do %>
              <div class={[
                "mb-4 rounded-lg border p-3 flex items-start justify-between gap-3",
                @toast.kind == :success && "border-green-200 bg-green-50",
                @toast.kind == :info && "border-gray-200 bg-gray-50"
              ]}>
                <div class="text-sm text-gray-900">{@toast.msg}</div>
                <.hq_button variant="ghost" phx-click="clear_toast" type="button">Dismiss</.hq_button>
              </div>
            <% end %>
            
    <!-- Header -->
            <div class="mb-6">
              <div class="flex items-center space-x-3 mb-2">
                <div class="w-10 h-10 bg-gradient-to-br from-red-500 to-orange-600 rounded-lg flex items-center justify-center">
                  <.hq_icon name="shield_alert" class="w-6 h-6 text-white" />
                </div>
                <div>
                  <h1 class="text-2xl font-bold text-gray-900">Holds &amp; Quarantine</h1>
                  <p class="text-gray-500 text-sm">Manage quality holds and quarantine workflows</p>
                </div>
              </div>
            </div>
            
    <!-- Summary Cards -->
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
              <.hq_card class="bg-gradient-to-br from-red-50 to-red-100 border-red-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-red-600 font-medium mb-1">Active Holds</p>
                    <p class="text-2xl font-bold text-red-900">{@active_count}</p>
                  </div>
                  <.hq_icon name="shield_alert" class="w-8 h-8 text-red-500 opacity-50" />
                </div>
              </.hq_card>

              <.hq_card class="bg-gradient-to-br from-orange-50 to-orange-100 border-orange-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-orange-600 font-medium mb-1">Units On Hold</p>
                    <p class="text-2xl font-bold text-orange-900">{@units_on_hold}</p>
                  </div>
                  <.hq_icon name="alert_triangle" class="w-8 h-8 text-orange-500 opacity-50" />
                </div>
              </.hq_card>

              <.hq_card class="bg-gradient-to-br from-green-50 to-green-100 border-green-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-green-600 font-medium mb-1">Released (7d)</p>
                    <p class="text-2xl font-bold text-green-900">{@released_7d}</p>
                  </div>
                  <.hq_icon name="check_circle" class="w-8 h-8 text-green-500 opacity-50" />
                </div>
              </.hq_card>

              <.hq_card class="bg-gradient-to-br from-gray-50 to-gray-100 border-gray-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-gray-600 font-medium mb-1">Avg Hold Time</p>
                    <p class="text-2xl font-bold text-gray-900">{format_days(@avg_days)}</p>
                  </div>
                  <.hq_icon name="clock" class="w-8 h-8 text-gray-500 opacity-50" />
                </div>
              </.hq_card>
            </div>
            
    <!-- Tab Navigation -->
            <div class="border-b border-gray-200 mb-6">
              <nav class="flex space-x-1 overflow-x-auto">
                <.hq_tab_button active={@active_tab == "active"} tab="active" label="Active Holds">
                  <.hq_badge variant="danger">{@active_count}</.hq_badge>
                </.hq_tab_button>

                <.hq_tab_button
                  active={@active_tab == "released"}
                  tab="released"
                  label="Released (7d)"
                />

                <.hq_tab_button active={@active_tab == "new"} tab="new" label="New Hold" />
              </nav>
            </div>
            
    <!-- Active Holds -->
            <%= if @active_tab == "active" do %>
              <.hq_panel title="Active Holds">
                <div class="space-y-3">
                  <%= for hold <- @active_holds do %>
                    <% cfg = hold_type_config(hold.type) %>
                    <div
                      class="p-4 border-2 border-gray-200 rounded-lg hover:border-red-300 hover:shadow-md transition-all cursor-pointer"
                      phx-click="open_hold"
                      phx-value-id={hold.id}
                    >
                      <div class="flex items-start justify-between mb-3 gap-3">
                        <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
                          <h3 class="font-semibold text-gray-900">{hold.id}</h3>

                          <span class={[
                            "inline-flex items-center space-x-1 px-2 py-1 rounded text-xs font-semibold",
                            cfg.color
                          ]}>
                            <.hq_icon name={cfg.icon} class="w-3 h-3" />
                            <span>{cfg.label}</span>
                          </span>

                          <.hq_badge variant="danger">{hold.status}</.hq_badge>
                        </div>

                        <.hq_button
                          size="sm"
                          variant="secondary"
                          type="button"
                          phx-click="open_hold"
                          phx-value-id={hold.id}
                          phx-stop-propagation
                        >
                          Review
                        </.hq_button>
                      </div>

                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm mb-2">
                        <div>
                          <span class="text-gray-600">Lots:</span>
                          <div class="mt-1 flex flex-wrap gap-2">
                            <%= for lot <- hold.lots do %>
                              <.lot_chip lot_id={lot} expiry_date="2024-12-20" days_until_expiry={5} />
                            <% end %>
                          </div>
                        </div>

                        <div>
                          <span class="text-gray-600">Units:</span>
                          <span class="ml-2 font-semibold text-gray-900">{hold.units} units</span>
                        </div>

                        <div class="sm:col-span-2">
                          <span class="text-gray-600">Reason:</span>
                          <p class="text-gray-900 mt-1">{hold.reason}</p>
                        </div>

                        <div>
                          <span class="text-gray-600">Created By:</span>
                          <span class="ml-2 text-gray-900">{hold.created_by}</span>
                        </div>

                        <div>
                          <span class="text-gray-600">Created:</span>
                          <span class="ml-2 text-gray-900">{hold.created_at}</span>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <%= if @active_holds == [] do %>
                    <div class="p-6 border-2 border-dashed border-gray-300 rounded-lg bg-gray-50">
                      <p class="text-sm font-semibold text-gray-900">No active holds</p>
                      <p class="text-xs text-gray-600 mt-1">
                        Create a new hold when product must be blocked from picking/shipping.
                      </p>
                      <div class="mt-3">
                        <.hq_button phx-click="set_tab" phx-value-tab="new" type="button">
                          Create New Hold
                        </.hq_button>
                      </div>
                    </div>
                  <% end %>
                </div>
              </.hq_panel>
            <% end %>
            
    <!-- Released Holds -->
            <%= if @active_tab == "released" do %>
              <.hq_panel title="Released Holds">
                <div class="mb-4 grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <form phx-change="released_search" class="sm:col-span-1">
                    <input
                      name="released_search"
                      value={@released_search}
                      placeholder="Search by ID or lot..."
                      class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                    />
                  </form>

                  <form phx-change="released_disposition" class="sm:col-span-1">
                    <select
                      name="released_disposition"
                      class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                    >
                      <option value="all" selected={@released_disposition == "all"}>
                        All dispositions
                      </option>
                      <option value="released" selected={@released_disposition == "released"}>
                        Released only
                      </option>
                      <option value="scrapped" selected={@released_disposition == "scrapped"}>
                        Scrapped only
                      </option>
                    </select>
                  </form>

                  <form phx-change="released_range" class="sm:col-span-1">
                    <select
                      name="released_range"
                      class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                    >
                      <option value="7" selected={@released_range == "7"}>Last 7 days</option>
                      <option value="30" selected={@released_range == "30"}>Last 30 days</option>
                      <option value="90" selected={@released_range == "90"}>Last 90 days</option>
                    </select>
                  </form>
                </div>

                <div class="space-y-3">
                  <%= for hold <- @released_page_items do %>
                    <% cfg = hold_type_config(hold.type) %>
                    <div class="p-4 border border-gray-200 rounded-lg hover:border-gray-300 hover:shadow-sm transition-all">
                      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 mb-3">
                        <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
                          <h3 class="font-semibold text-gray-900">{hold.id}</h3>

                          <span class={[
                            "inline-flex items-center space-x-1 px-2 py-1 rounded text-xs font-semibold",
                            cfg.color
                          ]}>
                            <.hq_icon name={cfg.icon} class="w-3 h-3" />
                            <span>{cfg.label}</span>
                          </span>

                          <%= if hold.disposition == "released" do %>
                            <.hq_badge variant="success">✓ Released</.hq_badge>
                          <% else %>
                            <.hq_badge variant="neutral">✕ Scrapped</.hq_badge>
                          <% end %>
                        </div>

                        <div class="text-right text-xs text-gray-600">
                          <div class="flex items-center justify-end space-x-1">
                            <.hq_icon name="clock" class="w-3 h-3" />
                            <span>Hold duration: {hold.hold_duration}</span>
                          </div>
                        </div>
                      </div>

                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm mb-3">
                        <div>
                          <span class="text-gray-600">Lots:</span>
                          <div class="mt-1 flex flex-wrap gap-2">
                            <%= for lot <- hold.lots do %>
                              <.lot_chip lot_id={lot} expiry_date="2024-12-20" days_until_expiry={5} />
                            <% end %>
                          </div>
                        </div>

                        <div>
                          <span class="text-gray-600">Units:</span>
                          <span class="ml-2 font-semibold text-gray-900">{hold.units} units</span>
                        </div>

                        <div>
                          <span class="text-gray-600">Created:</span>
                          <span class="ml-2 text-gray-900">{hold.created_at}</span>
                        </div>

                        <div>
                          <span class="text-gray-600">Released:</span>
                          <span class="ml-2 text-gray-900">{hold.released_at}</span>
                        </div>

                        <div>
                          <span class="text-gray-600">Released By:</span>
                          <span class="ml-2 text-gray-900">{hold.released_by}</span>
                        </div>
                      </div>

                      <div class="pt-3 border-t border-gray-200">
                        <p class="text-xs text-gray-600 mb-1">Original Reason:</p>
                        <p class="text-sm text-gray-700 mb-2">{hold.reason}</p>
                        <p class="text-xs text-gray-600 mb-1">Resolution:</p>
                        <p class="text-sm text-gray-700 bg-gray-50 p-2 rounded border border-gray-200">
                          {hold.resolution_notes}
                        </p>
                      </div>
                    </div>
                  <% end %>

                  <%= if @released_total == 0 do %>
                    <div class="p-6 border border-dashed border-gray-300 rounded-lg bg-gray-50">
                      <p class="text-sm font-semibold text-gray-900">No results</p>
                      <p class="text-xs text-gray-600 mt-1">
                        Try clearing search or changing the disposition filter.
                      </p>
                    </div>
                  <% end %>
                </div>

                <div class="mt-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 text-sm text-gray-600">
                  <span>
                    Showing {@page_info.showing_from}-{@page_info.showing_to} of {@released_total}
                  </span>

                  <div class="flex space-x-2">
                    <.hq_button
                      size="sm"
                      variant="secondary"
                      phx-click="released_prev"
                      disabled={@released_page <= 1}
                      type="button"
                    >
                      Previous
                    </.hq_button>

                    <.hq_button
                      size="sm"
                      variant="secondary"
                      phx-click="released_next"
                      disabled={@released_page >= @page_info.total_pages}
                      type="button"
                    >
                      Next
                    </.hq_button>
                  </div>
                </div>
              </.hq_panel>
            <% end %>
            
    <!-- New Hold -->
            <%= if @active_tab == "new" do %>
              <.hq_panel title="Create New Hold">
                <div class="space-y-6">
                  <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
                    <div class="flex items-start space-x-3">
                      <.hq_icon name="shield_alert" class="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
                      <div class="text-sm text-red-900">
                        <p class="font-medium mb-1">Quality Hold</p>
                        <p class="text-red-800 text-xs">
                          Placing a hold blocks affected lots/units from being picked or shipped. Disposition actions should be recorded in the audit trail.
                        </p>
                      </div>
                    </div>
                  </div>

                  <form phx-change="new_hold_change" class="space-y-6">
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-2">Hold Type</label>
                      <select
                        name="new_hold[type]"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                      >
                        <option value="" selected={@new_hold.type == ""}>Select Hold Type</option>
                        <option value="qa" selected={@new_hold.type == "qa"}>QA Hold</option>
                        <option value="micro" selected={@new_hold.type == "micro"}>
                          Microbiological Hold
                        </option>
                        <option value="label" selected={@new_hold.type == "label"}>Label Hold</option>
                        <option value="temperature" selected={@new_hold.type == "temperature"}>
                          Temperature Excursion
                        </option>
                        <option
                          value="customer-complaint"
                          selected={@new_hold.type == "customer-complaint"}
                        >
                          Customer Complaint
                        </option>
                        <option value="investigation" selected={@new_hold.type == "investigation"}>
                          Investigation
                        </option>
                      </select>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-2">
                        Affected Lot(s)
                      </label>
                      <input
                        type="text"
                        name="new_hold[lots]"
                        value={@new_hold.lots}
                        placeholder="e.g., LOT-087, LOT-088"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                      />
                      <p class="text-xs text-gray-500 mt-1">
                        Comma- or space-separated list of lot IDs
                      </p>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-2">
                        Reason (required)
                      </label>
                      <textarea
                        name="new_hold[reason]"
                        rows="3"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        placeholder="Provide detailed reason for this hold..."
                      ><%= @new_hold.reason %></textarea>
                    </div>

                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-2">
                        Additional Notes
                      </label>
                      <textarea
                        name="new_hold[notes]"
                        rows="3"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        placeholder="Any additional context or instructions..."
                      ><%= @new_hold.notes %></textarea>
                    </div>
                  </form>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Attach Documents (lab reports, photos, etc.)
                    </label>
                    <button
                      type="button"
                      phx-click="new_hold_upload_stub"
                      class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-gray-400 transition-colors"
                    >
                      <.hq_icon name="upload" class="w-8 h-8 text-gray-400 mx-auto mb-2" />
                      <p class="text-sm text-gray-600">Click to upload or drag and drop</p>
                      <p class="text-xs text-gray-500 mt-1">PDF, PNG, JPG up to 10MB</p>
                    </button>
                  </div>

                  <div class="flex flex-col sm:flex-row sm:justify-end gap-3 pt-6 border-t border-gray-200">
                    <.hq_button variant="secondary" phx-click="new_hold_cancel" type="button">
                      Cancel
                    </.hq_button>

                    <.hq_button
                      phx-click="new_hold_create"
                      disabled={
                        String.trim(@new_hold.type) == "" or String.trim(@new_hold.lots) == "" or
                          String.trim(@new_hold.reason) == ""
                      }
                      type="button"
                    >
                      Create Hold
                    </.hq_button>
                  </div>
                </div>
              </.hq_panel>
            <% end %>
            
    <!-- Hold Detail Drawer (Active holds only) -->
            <%= if @selected_hold do %>
              <div class="fixed inset-0 z-40 bg-black/50" phx-click="close_hold" />

              <div class="fixed right-0 top-0 z-50 h-full w-full max-w-2xl bg-white shadow-2xl overflow-y-auto">
                <div class="p-6">
                  <div class="flex items-start justify-between mb-6">
                    <div>
                      <h2 class="text-xl font-bold text-gray-900">Hold Detail</h2>
                      <p class="text-sm text-gray-500 mt-1">{@selected_hold.id}</p>
                    </div>

                    <button
                      type="button"
                      phx-click="close_hold"
                      class="text-gray-400 hover:text-gray-600"
                    >
                      ✕
                    </button>
                  </div>

                  <% cfg = hold_type_config(@selected_hold.type) %>

                  <.hq_card class="mb-6">
                    <h3 class="text-sm font-semibold text-gray-900 mb-4">Hold Information</h3>

                    <div class="space-y-3 text-sm">
                      <div class="flex justify-between items-center gap-3">
                        <span class="text-gray-600">Type:</span>
                        <span class={[
                          "px-2 py-1 rounded text-xs font-semibold inline-flex items-center gap-1",
                          cfg.color
                        ]}>
                          <.hq_icon name={cfg.icon} class="w-3 h-3" />
                          <span>{cfg.label}</span>
                        </span>
                      </div>

                      <div class="flex justify-between items-center gap-3">
                        <span class="text-gray-600">Status:</span>
                        <.hq_badge variant="danger">{@selected_hold.status}</.hq_badge>
                      </div>

                      <div class="flex justify-between gap-3">
                        <span class="text-gray-600">Created By:</span>
                        <span class="font-semibold text-gray-900">{@selected_hold.created_by}</span>
                      </div>

                      <div class="flex justify-between gap-3">
                        <span class="text-gray-600">Created:</span>
                        <span class="text-gray-900">{@selected_hold.created_at}</span>
                      </div>

                      <div class="pt-3 border-t border-gray-200">
                        <span class="text-gray-600">Affected Lots:</span>
                        <div class="mt-2 flex flex-wrap gap-2">
                          <%= for lot <- @selected_hold.lots do %>
                            <.lot_chip lot_id={lot} expiry_date="2024-12-20" days_until_expiry={5} />
                          <% end %>
                        </div>
                      </div>

                      <div>
                        <span class="text-gray-600">Units On Hold:</span>
                        <span class="ml-2 font-bold text-gray-900">{@selected_hold.units} units</span>
                      </div>
                    </div>
                  </.hq_card>

                  <.hq_card class="mb-6">
                    <h3 class="text-sm font-semibold text-gray-900 mb-4">
                      Reason &amp; Documentation
                    </h3>

                    <div class="space-y-3">
                      <p class="text-sm text-gray-700 bg-gray-50 p-3 rounded border border-gray-200">
                        {@selected_hold.reason}
                      </p>

                      <%= if @selected_hold.attachments != [] do %>
                        <div>
                          <p class="text-xs text-gray-600 mb-2">Attachments:</p>
                          <div class="space-y-2">
                            <%= for file <- @selected_hold.attachments do %>
                              <div class="flex items-center justify-between gap-3 text-sm">
                                <div class="flex items-center gap-2">
                                  <.hq_icon name="upload" class="w-4 h-4 text-gray-400" />
                                  <span class="text-gray-700">{file}</span>
                                </div>
                                <.hq_button
                                  variant="ghost"
                                  phx-click="download_attachment"
                                  phx-value-file={file}
                                  type="button"
                                >
                                  Download
                                </.hq_button>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </.hq_card>

                  <.hq_card>
                    <h3 class="text-sm font-semibold text-gray-900 mb-4">Disposition</h3>

                    <form phx-change="resolution_change" class="space-y-2">
                      <label class="block text-sm font-medium text-gray-700">Resolution Notes</label>
                      <textarea
                        name="resolution_notes"
                        rows="4"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        placeholder="Document the resolution and any corrective actions taken..."
                      ><%= @resolution_notes %></textarea>
                      <p class="text-xs text-gray-500">
                        Tip: Include root cause, checks performed, and who approved the disposition.
                      </p>
                    </form>

                    <div class="flex flex-col sm:flex-row gap-3 mt-6">
                      <.hq_button
                        variant="secondary"
                        class="flex-1 text-red-700 hover:bg-red-50"
                        phx-click="scrap_hold"
                        phx-value-id={@selected_hold.id}
                        type="button"
                      >
                        <span class="inline-flex items-center gap-2">
                          <.hq_icon name="x_circle" class="w-4 h-4" /> Scrap Units
                        </span>
                      </.hq_button>

                      <.hq_button
                        class="flex-1"
                        phx-click="release_hold"
                        phx-value-id={@selected_hold.id}
                        type="button"
                      >
                        <span class="inline-flex items-center gap-2">
                          <.hq_icon name="check_circle" class="w-4 h-4" /> Release Hold
                        </span>
                      </.hq_button>
                    </div>

                    <p class="text-xs text-gray-500 mt-3">
                      Releasing makes units available for picking again. Dispositions should be recorded in the audit trail.
                    </p>
                  </.hq_card>
                </div>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end

  # --------------------
  # Function components
  # --------------------

  attr :active, :boolean, required: true
  attr :tab, :string, required: true
  attr :label, :string, required: true
  slot :inner_block

  def hq_tab_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="set_tab"
      phx-value-tab={@tab}
      class={[
        "flex items-center space-x-2 px-4 py-3 text-sm font-medium transition-all duration-200 border-b-2 -mb-px whitespace-nowrap",
        @active && "border-[#2E7D32] text-[#2E7D32]",
        !@active && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
      ]}
    >
      <span>{@label}</span>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :title, :string, default: nil
  slot :inner_block, required: true

  def hq_panel(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded-xl p-5">
      <%= if @title do %>
        <div class="mb-4">
          <h2 class="text-sm font-semibold text-gray-900">{@title}</h2>
        </div>
      <% end %>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def hq_card(assigns) do
    ~H"""
    <div class={["bg-white border border-gray-200 rounded-xl p-4", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :variant, :string, default: "neutral", values: ["neutral", "danger", "success"]
  slot :inner_block, required: true

  def hq_badge(assigns) do
    class =
      case assigns.variant do
        "danger" ->
          "inline-flex items-center rounded-full bg-red-100 text-red-800 px-2 py-0.5 text-xs font-semibold"

        "success" ->
          "inline-flex items-center rounded-full bg-green-100 text-green-800 px-2 py-0.5 text-xs font-semibold"

        _ ->
          "inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 text-xs font-semibold"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={@class}>{render_slot(@inner_block)}</span>
    """
  end

  attr :variant, :string, default: "primary", values: ["primary", "secondary", "ghost"]
  attr :size, :string, default: "md", values: ["md", "sm"]
  attr :type, :string, default: "button"
  attr :class, :string, default: nil

  attr :rest, :global, include: ~w(
      disabled form name value
      phx-click phx-change phx-submit phx-value-id phx-value-tab phx-value-file
      phx-stop-propagation
    )

  slot :inner_block, required: true

  def hq_button(assigns) do
    base =
      "inline-flex items-center justify-center gap-2 font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#2E7D32] disabled:opacity-50 disabled:pointer-events-none"

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 rounded-full hover:bg-gray-200"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"
        _ -> "bg-[#2E7D32] text-white rounded-full hover:brightness-95"
      end

    size =
      case assigns.size do
        "sm" ->
          case assigns.variant do
            "ghost" -> ""
            _ -> "h-8 px-3 text-xs"
          end

        _ ->
          case assigns.variant do
            "ghost" -> ""
            _ -> "h-9 px-4 text-sm"
          end
      end

    assigns = assign(assigns, :btn_class, [base, variant, size, assigns.class])

    ~H"""
    <button type={@type} class={@btn_class} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :lot_id, :string, required: true
  attr :expiry_date, :string, required: true
  attr :days_until_expiry, :integer, required: true

  def lot_chip(assigns) do
    urgent? = assigns.days_until_expiry <= 5
    assigns = assign(assigns, :urgent?, urgent?)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-semibold",
      @urgent? && "border-orange-200 bg-orange-50 text-orange-800",
      !@urgent? && "border-gray-200 bg-gray-50 text-gray-700"
    ]}>
      <span class="font-mono">{@lot_id}</span>
      <span class="mx-1 text-gray-400">•</span>
      <span>Exp {@expiry_date}</span>
      <span class="mx-1 text-gray-400">•</span>
      <span>{@days_until_expiry}d</span>
    </span>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "w-4 h-4"

  def hq_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "shield_alert" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 2l8 4v6c0 5-3.4 9.4-8 10-4.6-.6-8-5-8-10V6l8-4z"
          />
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v5" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 16h.01" />
        </svg>
      <% "alert_triangle" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v4m0 4h.01" />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"
          />
        </svg>
      <% "check_circle" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4" />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 22a10 10 0 1 0-10-10 10 10 0 0 0 10 10z"
          />
        </svg>
      <% "clock" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 22a10 10 0 1 0-10-10 10 10 0 0 0 10 10z"
          />
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6l4 2" />
        </svg>
      <% "beaker" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 2h6" />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M10 2v6l-5.5 9.5A3 3 0 0 0 7.1 22h9.8a3 3 0 0 0 2.6-4.5L14 8V2"
          />
          <path stroke-linecap="round" stroke-linejoin="round" d="M8 16h8" />
        </svg>
      <% "tag" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M20 13l-7 7-11-11V2h7l11 11z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M7 7h.01" />
        </svg>
      <% "thermometer" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M14 14.76V5a2 2 0 0 0-4 0v9.76a4 4 0 1 0 4 0z"
          />
        </svg>
      <% "message_square" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4v8z"
          />
        </svg>
      <% "upload" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 16V4" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M7 9l5-5 5 5" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M4 20h16" />
        </svg>
      <% "x_circle" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 22a10 10 0 1 0-10-10 10 10 0 0 0 10 10z"
          />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 9l-6 6" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 9l6 6" />
        </svg>
      <% _ -> %>
        <span class={@class} aria-hidden="true"></span>
    <% end %>
    """
  end

  # --------------------
  # Helpers
  # --------------------

  defp toast(socket, kind, msg), do: assign(socket, :toast, %{kind: kind, msg: msg})

  defp hold_type_config(type) do
    case type do
      "qa" ->
        %{color: "bg-yellow-100 text-yellow-800", icon: "alert_triangle", label: "QA Hold"}

      "micro" ->
        %{color: "bg-red-100 text-red-800", icon: "beaker", label: "Micro Hold"}

      "label" ->
        %{color: "bg-orange-100 text-orange-800", icon: "tag", label: "Label Hold"}

      "temperature" ->
        %{color: "bg-blue-100 text-blue-800", icon: "thermometer", label: "Temperature Hold"}

      "customer-complaint" ->
        %{
          color: "bg-purple-100 text-purple-800",
          icon: "message_square",
          label: "Customer Complaint"
        }

      "investigation" ->
        %{color: "bg-gray-100 text-gray-800", icon: "alert_triangle", label: "Investigation"}

      _ ->
        %{color: "bg-gray-100 text-gray-800", icon: "alert_triangle", label: "Hold"}
    end
  end

  defp filter_released(holds, search, disposition) do
    s = search |> to_string() |> String.trim() |> String.downcase()

    holds
    |> Enum.filter(fn h ->
      matches_search =
        if s == "" do
          true
        else
          hay =
            [h.id | h.lots || []]
            |> Enum.join(" ")
            |> String.downcase()

          String.contains?(hay, s)
        end

      matches_disp =
        case disposition do
          "released" -> h.disposition == "released"
          "scrapped" -> h.disposition == "scrapped"
          _ -> true
        end

      matches_search and matches_disp
    end)
  end

  defp paginate(items, page, page_size) do
    total = length(items)
    total_pages = if total == 0, do: 1, else: ceil_div(total, page_size)
    page = max(min(page, total_pages), 1)

    from = (page - 1) * page_size
    page_items = items |> Enum.drop(from) |> Enum.take(page_size)

    showing_from = if total == 0, do: 0, else: from + 1
    showing_to = min(from + length(page_items), total)

    {page_items,
     %{
       page: page,
       total_pages: total_pages,
       showing_from: showing_from,
       showing_to: showing_to
     }}
  end

  defp ceil_div(a, b) when is_integer(a) and is_integer(b) and b > 0 do
    div(a + b - 1, b)
  end

  defp now_string() do
    dt = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:minute)
    "#{pad4(dt.year)}-#{pad2(dt.month)}-#{pad2(dt.day)} #{pad2(dt.hour)}:#{pad2(dt.minute)}"
  end

  defp duration_string(created_at, released_at) do
    with {:ok, c} <- parse_naive(created_at),
         {:ok, r} <- parse_naive(released_at) do
      seconds = NaiveDateTime.diff(r, c, :second)
      format_duration(seconds)
    else
      _ -> "—"
    end
  end

  defp avg_hold_days(released_holds) do
    {sum, cnt} =
      released_holds
      |> Enum.reduce({0, 0}, fn h, {sum, cnt} ->
        with {:ok, c} <- parse_naive(h.created_at),
             {:ok, r} <- parse_naive(h.released_at) do
          {sum + NaiveDateTime.diff(r, c, :second), cnt + 1}
        else
          _ -> {sum, cnt}
        end
      end)

    if cnt == 0, do: 0.0, else: sum / cnt / 86_400
  end

  defp format_days(days) when is_float(days), do: "#{Float.round(days, 1)}d"
  defp format_days(_), do: "—"

  defp parse_naive(str) when is_binary(str) do
    s = String.trim(str)

    case String.split(s, " ", parts: 2) do
      [date, time] ->
        iso = "#{date}T#{time}:00"
        NaiveDateTime.from_iso8601(iso)

      _ ->
        {:error, :invalid}
    end
  end

  defp format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = seconds / 3600

    cond do
      hours < 24 -> "#{Float.round(hours, 1)} hours"
      true -> "#{Float.round(hours / 24, 1)} days"
    end
  end

  defp next_hold_id(active_holds, released_holds) do
    ids = Enum.map(active_holds ++ released_holds, & &1.id)

    max_n =
      ids
      |> Enum.reduce(0, fn id, acc ->
        case Regex.run(~r/HOLD-(\d+)/, id, capture: :all_but_first) do
          [n] ->
            case Integer.parse(n) do
              {i, _} -> max(acc, i)
              :error -> acc
            end

          _ ->
            acc
        end
      end)

    "HOLD-" <> pad3(max_n + 1)
  end

  defp estimate_units_from_lots(lots) when is_list(lots), do: max(length(lots) * 10, 1)

  defp pad2(n) when is_integer(n) and n < 10, do: "0" <> Integer.to_string(n)
  defp pad2(n) when is_integer(n), do: Integer.to_string(n)

  defp pad3(n) when is_integer(n) and n < 10, do: "00" <> Integer.to_string(n)
  defp pad3(n) when is_integer(n) and n < 100, do: "0" <> Integer.to_string(n)
  defp pad3(n) when is_integer(n), do: Integer.to_string(n)

  defp pad4(n) when is_integer(n) and n < 10, do: "000" <> Integer.to_string(n)
  defp pad4(n) when is_integer(n) and n < 100, do: "00" <> Integer.to_string(n)
  defp pad4(n) when is_integer(n) and n < 1000, do: "0" <> Integer.to_string(n)
  defp pad4(n) when is_integer(n), do: Integer.to_string(n)
end
