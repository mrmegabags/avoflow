defmodule AvoflowWeb.CycleCountsLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar

  @expected_units 58

  @impl true
  def mount(_params, _session, socket) do
    scheduled_counts = [
      %{
        id: "CC-2024-045",
        date: "2024-12-16",
        location: "Purée Fridge",
        bins: "A-10 to A-15",
        skus: "All",
        status: "scheduled"
      },
      %{
        id: "CC-2024-046",
        date: "2024-12-17",
        location: "Dispatch Chiller",
        bins: "C-01 to C-05",
        skus: "All",
        status: "scheduled"
      }
    ]

    # Completed example (mock)
    completed_counts = [
      %{
        id: "CC-2024-044",
        date: "2024-12-14",
        location: "Dispatch Chiller",
        bins: "C-01 to C-03",
        skus: "All",
        status: "completed",
        summary: %{items: 42, variances: 0, bins: 3, scanned_units: 58}
      }
    ]

    # Investigation example (mock)
    investigations = [
      %{
        id: "CC-2024-045-VAR-001",
        cc_id: "CC-2024-045",
        sku: "SSB-200",
        lot: "LOT-087",
        variance: -3,
        status: "investigating",
        steps: [
          %{status: "done", text: "Checked adjacent bins A-09, A-11: No units found"},
          %{status: "done", text: "Reviewed stock movements (last 48h): All recorded"},
          %{status: "todo", text: "Reviewing CCTV footage (Zone-A, 2024-12-13 to 2024-12-15)"}
        ],
        notes: []
      }
    ]

    socket =
      socket
      |> assign(:q, "")
      |> assign(:unread_count, 2)
      |> assign(:user_label, "Warehouse")
      |> assign(:active_tab, "scheduled")
      |> assign(:scheduled_filter, "")
      |> assign(:expected_units, @expected_units)
      |> assign(:scheduled_counts, scheduled_counts)
      |> assign(:completed_counts, completed_counts)
      |> assign(:in_progress_count, nil)
      |> assign(:scan_code, "")
      |> assign(:scanned_units, 0)
      |> assign(:recent_scans, [])
      |> assign(:add_qty, "")
      |> assign(:show_variances_only, false)
      |> assign(:toast, nil)
      |> assign(:investigations, investigations)
      |> assign(:note_for, nil)
      |> assign(:note_draft, "")
      |> assign(:show_completed_id, nil)

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
  # Navigation / tabs
  # --------------------

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("set_scheduled_filter", %{"scheduled_filter" => val}, socket) do
    {:noreply, assign(socket, :scheduled_filter, val || "")}
  end

  @impl true
  def handle_event("clear_toast", _params, socket) do
    {:noreply, assign(socket, :toast, nil)}
  end

  # --------------------
  # Scheduled -> In progress flow
  # --------------------

  @impl true
  def handle_event("schedule_new", _params, socket) do
    {:noreply, toast(socket, :info, "Scheduling is a placeholder in this mock page.")}
  end

  @impl true
  def handle_event("start_next_scheduled", _params, socket) do
    case next_scheduled(socket.assigns.scheduled_counts) do
      nil ->
        {:noreply, toast(socket, :info, "No scheduled counts available to start.")}

      count ->
        start_from_scheduled(socket, count)
    end
  end

  @impl true
  def handle_event("start_count", %{"id" => id}, socket) do
    count = Enum.find(socket.assigns.scheduled_counts, &(&1.id == id))

    if count do
      start_from_scheduled(socket, count)
    else
      {:noreply, toast(socket, :info, "That scheduled count is no longer available.")}
    end
  end

  @impl true
  def handle_event("pause_count", _params, socket) do
    # Keep state, return to Scheduled so user can bounce around.
    {:noreply,
     socket
     |> assign(:active_tab, "scheduled")
     |> toast(:info, "Saved progress. You can resume anytime.")}
  end

  @impl true
  def handle_event("complete_count", _params, socket) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, socket}
    else
      variances = Enum.count(ic.items, &(&1.variance != 0))

      completed =
        %{
          id: ic.id,
          date: ic.started_date,
          location: ic.location,
          bins: ic.bins,
          skus: "All",
          status: "completed",
          summary: %{
            items: length(ic.items),
            variances: variances,
            bins: ic.total_bins,
            scanned_units: socket.assigns.scanned_units
          }
        }

      socket =
        socket
        |> assign(:completed_counts, [completed | socket.assigns.completed_counts])
        |> assign(:in_progress_count, nil)
        |> assign(:active_tab, "completed")
        |> assign(:scanned_units, 0)
        |> assign(:recent_scans, [])
        |> assign(:scan_code, "")
        |> assign(:add_qty, "")
        |> assign(:show_variances_only, false)
        |> toast(:success, "Cycle count completed and moved to Completed.")

      {:noreply, socket}
    end
  end

  # --------------------
  # Bin navigation
  # --------------------

  @impl true
  def handle_event("previous_bin", _params, socket) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, socket}
    else
      if ic.completed_bins <= 0 do
        {:noreply, toast(socket, :info, "Already at the first bin.")}
      else
        new_completed = ic.completed_bins - 1
        new_bin = bin_shift(ic.current_bin, -1)

        ic =
          ic
          |> Map.put(:completed_bins, new_completed)
          |> Map.put(:current_bin, new_bin)

        {:noreply, assign(socket, :in_progress_count, ic)}
      end
    end
  end

  @impl true
  def handle_event("next_bin", _params, socket) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, socket}
    else
      current_index = ic.completed_bins + 1

      if current_index >= ic.total_bins do
        {:noreply, toast(socket, :info, "Already at the last bin. You can complete the count.")}
      else
        new_completed = ic.completed_bins + 1
        new_bin = bin_shift(ic.current_bin, 1)

        ic =
          ic
          |> Map.put(:completed_bins, new_completed)
          |> Map.put(:current_bin, new_bin)

        {:noreply, assign(socket, :in_progress_count, ic)}
      end
    end
  end

  # --------------------
  # Count sheet actions
  # --------------------

  @impl true
  def handle_event("set_actual", %{"idx" => idx, "actual" => actual_str}, socket) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, socket}
    else
      idx = parse_int(idx, 0)
      actual = parse_int(actual_str, 0)

      items =
        ic.items
        |> Enum.with_index()
        |> Enum.map(fn {item, i} ->
          if i == idx do
            item
            |> Map.put(:actual, actual)
            |> recalc_item()
          else
            item
          end
        end)

      ic = normalize_in_progress(%{ic | items: items})
      {:noreply, assign(socket, :in_progress_count, ic)}
    end
  end

  @impl true
  def handle_event("quick_match", %{"idx" => idx}, socket) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, socket}
    else
      idx = parse_int(idx, 0)

      items =
        ic.items
        |> Enum.with_index()
        |> Enum.map(fn {item, i} ->
          if i == idx do
            item
            |> Map.put(:actual, item.expected)
            |> recalc_item()
          else
            item
          end
        end)

      ic = normalize_in_progress(%{ic | items: items})

      {:noreply,
       socket
       |> assign(:in_progress_count, ic)
       |> toast(:success, "Set actual = expected for that row.")}
    end
  end

  @impl true
  def handle_event("fill_actuals_expected", _params, socket) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, socket}
    else
      items =
        Enum.map(ic.items, fn item ->
          item
          |> Map.put(:actual, item.expected)
          |> recalc_item()
        end)

      ic = normalize_in_progress(%{ic | items: items})

      {:noreply,
       socket
       |> assign(:in_progress_count, ic)
       |> toast(:success, "Filled all Actual values to match Expected.")}
    end
  end

  @impl true
  def handle_event("toggle_variances_only", _params, socket) do
    {:noreply, update(socket, :show_variances_only, &(!&1))}
  end

  # --------------------
  # Scanning + alternative counting options
  # --------------------

  @impl true
  def handle_event("scan_change", %{"code" => code}, socket) do
    {:noreply, assign(socket, :scan_code, code || "")}
  end

  @impl true
  def handle_event("scan_submit", %{"code" => code}, socket) do
    code = String.trim(code || "")

    if code == "" do
      {:noreply, socket}
    else
      {:noreply, apply_scan(socket, code, :scanner)}
    end
  end

  @impl true
  def handle_event("demo_scan", %{"code" => code}, socket) do
    code = String.trim(code || "")

    if code == "" do
      {:noreply, socket}
    else
      {:noreply, apply_scan(socket, code, :demo)}
    end
  end

  @impl true
  def handle_event("reset_scans", _params, socket) do
    {:noreply,
     socket
     |> assign(:scanned_units, 0)
     |> assign(:recent_scans, [])
     |> assign(:scan_code, "")
     |> toast(:info, "Scan progress reset.")}
  end

  @impl true
  def handle_event("adjust_scans", %{"delta" => delta}, socket) do
    delta = parse_int(delta, 0)
    new_scanned = clamp(socket.assigns.scanned_units + delta, 0, socket.assigns.expected_units)

    socket =
      socket
      |> assign(:scanned_units, new_scanned)
      |> toast(:success, "Adjusted scanned units to #{new_scanned}.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_scans_expected", _params, socket) do
    socket =
      socket
      |> assign(:scanned_units, socket.assigns.expected_units)
      |> toast(:success, "Set scanned units to expected.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_qty_change", %{"add_qty" => val}, socket) do
    {:noreply, assign(socket, :add_qty, val || "")}
  end

  @impl true
  def handle_event("add_qty_submit", _params, socket) do
    qty = parse_int(socket.assigns.add_qty, 0)

    if qty <= 0 do
      {:noreply, toast(socket, :info, "Enter a positive quantity to add.")}
    else
      new_scanned = clamp(socket.assigns.scanned_units + qty, 0, socket.assigns.expected_units)

      recent =
        ["MANUAL+#{qty}" | socket.assigns.recent_scans]
        |> Enum.take(5)

      socket =
        socket
        |> assign(:scanned_units, new_scanned)
        |> assign(:recent_scans, recent)
        |> assign(:add_qty, "")
        |> toast(:success, "Added #{qty} units manually.")

      {:noreply, socket}
    end
  end

  # --------------------
  # Variances / Investigations (simple mock workflow)
  # --------------------

  @impl true
  def handle_event(
        "create_investigation",
        %{"sku" => sku, "lot" => lot, "variance" => variance},
        socket
      ) do
    ic = socket.assigns.in_progress_count

    if is_nil(ic) do
      {:noreply, toast(socket, :info, "Start a cycle count to create investigations.")}
    else
      inv_id = "#{ic.id}-#{sku}-#{lot}"

      exists? = Enum.any?(socket.assigns.investigations, &(&1.id == inv_id))

      socket =
        if exists? do
          toast(socket, :info, "Investigation already exists for #{sku} / #{lot}.")
        else
          inv = %{
            id: inv_id,
            cc_id: ic.id,
            sku: sku,
            lot: lot,
            variance: parse_int(variance, 0),
            status: "investigating",
            steps: [
              %{status: "todo", text: "Check adjacent bins"},
              %{status: "todo", text: "Review movements (last 48h)"},
              %{status: "todo", text: "Confirm root cause and corrective action"}
            ],
            notes: []
          }

          socket
          |> assign(:investigations, [inv | socket.assigns.investigations])
          |> toast(:success, "Created investigation for #{sku} / #{lot}.")
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_note", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:note_for, id) |> assign(:note_draft, "")}
  end

  @impl true
  def handle_event("note_change", %{"note" => note}, socket) do
    {:noreply, assign(socket, :note_draft, note || "")}
  end

  @impl true
  def handle_event("save_note", _params, socket) do
    id = socket.assigns.note_for
    note = String.trim(socket.assigns.note_draft || "")

    cond do
      is_nil(id) ->
        {:noreply, socket}

      note == "" ->
        {:noreply, toast(socket, :info, "Note cannot be empty.")}

      true ->
        investigations =
          Enum.map(socket.assigns.investigations, fn inv ->
            if inv.id == id do
              %{inv | notes: [note | inv.notes]}
            else
              inv
            end
          end)

        socket =
          socket
          |> assign(:investigations, investigations)
          |> assign(:note_for, nil)
          |> assign(:note_draft, "")
          |> toast(:success, "Added note.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_note", _params, socket) do
    {:noreply, socket |> assign(:note_for, nil) |> assign(:note_draft, "")}
  end

  @impl true
  def handle_event("close_investigation", %{"id" => id}, socket) do
    investigations =
      Enum.map(socket.assigns.investigations, fn inv ->
        if inv.id == id do
          %{inv | status: "closed"}
        else
          inv
        end
      end)

    {:noreply,
     socket |> assign(:investigations, investigations) |> toast(:success, "Investigation closed.")}
  end

  @impl true
  def handle_event("mark_step_done", %{"id" => id, "idx" => idx}, socket) do
    idx = parse_int(idx, 0)

    investigations =
      Enum.map(socket.assigns.investigations, fn inv ->
        if inv.id == id do
          steps =
            inv.steps
            |> Enum.with_index()
            |> Enum.map(fn {s, i} ->
              if i == idx, do: %{s | status: "done"}, else: s
            end)

          %{inv | steps: steps}
        else
          inv
        end
      end)

    {:noreply,
     socket |> assign(:investigations, investigations) |> toast(:success, "Marked step as done.")}
  end

  @impl true
  def handle_event("adjacent_bins", _params, socket) do
    {:noreply, toast(socket, :info, "Action placeholder: Search adjacent bins opened (mock).")}
  end

  @impl true
  def handle_event("check_movements", _params, socket) do
    {:noreply, toast(socket, :info, "Action placeholder: Movement check opened (mock).")}
  end

  # --------------------
  # Completed actions
  # --------------------

  @impl true
  def handle_event("view_completed", %{"id" => id}, socket) do
    {:noreply, assign(socket, :show_completed_id, id)}
  end

  @impl true
  def handle_event("close_completed_details", _params, socket) do
    {:noreply, assign(socket, :show_completed_id, nil)}
  end

  @impl true
  def handle_event("export_completed", %{"id" => id}, socket) do
    {:noreply, toast(socket, :info, "Export placeholder for #{id} (mock).")}
  end

  # --------------------
  # Render
  # --------------------

  @impl true
  def render(assigns) do
    scheduled_visible = filter_scheduled(assigns.scheduled_counts, assigns.scheduled_filter)
    scheduled_total = length(assigns.scheduled_counts)
    completed_total = length(assigns.completed_counts)
    in_progress_total = if(is_nil(assigns.in_progress_count), do: 0, else: 1)

    mismatches =
      case assigns.in_progress_count do
        nil -> []
        ic -> Enum.filter(ic.items, &(&1.variance != 0))
      end

    open_investigations =
      Enum.count(assigns.investigations, fn inv -> inv.status != "closed" end)

    variances_total = length(mismatches) + open_investigations

    next_scheduled_count = next_scheduled(assigns.scheduled_counts)

    {prev_disabled, next_disabled, next_label} =
      case assigns.in_progress_count do
        nil ->
          {true, true, "Next Bin →"}

        ic ->
          current_index = ic.completed_bins + 1
          prev_d = ic.completed_bins <= 0
          next_d = current_index >= ic.total_bins
          {prev_d, next_d, "Next Bin: " <> bin_shift(ic.current_bin, 1) <> " →"}
      end

    active_completed =
      if assigns.show_completed_id do
        Enum.find(assigns.completed_counts, &(&1.id == assigns.show_completed_id))
      end

    demo_codes = ["UNIT-QR-0001", "UNIT-QR-0002", "UNIT-QR-0003", "UNIT-QR-0010"]

    assigns =
      assigns
      |> assign(:scheduled_visible, scheduled_visible)
      |> assign(:scheduled_total, scheduled_total)
      |> assign(:completed_total, completed_total)
      |> assign(:in_progress_total, in_progress_total)
      |> assign(:variances_total, variances_total)
      |> assign(:mismatches, mismatches)
      |> assign(:open_investigations, open_investigations)
      |> assign(:next_scheduled_count, next_scheduled_count)
      |> assign(:prev_disabled, prev_disabled)
      |> assign(:next_disabled, next_disabled)
      |> assign(:next_label, next_label)
      |> assign(:active_completed, active_completed)
      |> assign(:demo_codes, demo_codes)

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
                <div class="text-sm text-gray-900">
                  {@toast.msg}
                </div>
                <.cc_button variant="ghost" phx-click="clear_toast" type="button">Dismiss</.cc_button>
              </div>
            <% end %>
            
    <!-- Header -->
            <div class="mb-6">
              <div class="flex items-center justify-between gap-4">
                <div class="flex items-center space-x-3">
                  <div class="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-lg flex items-center justify-center">
                    <.cc_icon name="clipboard_list" class="w-6 h-6 text-white" />
                  </div>

                  <div>
                    <h1 class="text-2xl font-bold text-gray-900">Cycle Counts</h1>
                    <p class="text-gray-500 text-sm">
                      Regular inventory verification and variance investigation
                    </p>
                  </div>
                </div>

                <div class="flex items-center gap-2">
                  <.cc_button
                    variant="secondary"
                    phx-click="start_next_scheduled"
                    class="hidden sm:inline-flex"
                  >
                    Quick Start
                  </.cc_button>

                  <.cc_button phx-click="schedule_new">
                    <:left_icon><.cc_icon name="plus" class="w-4 h-4" /></:left_icon>
                    Schedule New Count
                  </.cc_button>
                </div>
              </div>
            </div>
            
    <!-- At-a-glance -->
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
              <div class="bg-white border border-gray-200 rounded-xl p-4">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-xs font-semibold text-gray-500">Next scheduled</p>
                    <%= if @next_scheduled_count do %>
                      <p class="mt-1 text-sm font-semibold text-gray-900">
                        {@next_scheduled_count.id}
                      </p>
                      <p class="mt-1 text-xs text-gray-600">
                        {@next_scheduled_count.date} • {@next_scheduled_count.location}
                      </p>
                    <% else %>
                      <p class="mt-1 text-sm font-semibold text-gray-900">None</p>
                      <p class="mt-1 text-xs text-gray-600">No scheduled counts</p>
                    <% end %>
                  </div>

                  <.cc_button variant="ghost" phx-click="set_tab" phx-value-tab="scheduled">
                    View
                  </.cc_button>
                </div>
              </div>

              <div class="bg-white border border-gray-200 rounded-xl p-4">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-xs font-semibold text-gray-500">In progress</p>
                    <%= if @in_progress_count do %>
                      <p class="mt-1 text-sm font-semibold text-gray-900">{@in_progress_count.id}</p>
                      <p class="mt-1 text-xs text-gray-600">
                        Bin {@in_progress_count.current_bin} • {percent(
                          @in_progress_count.completed_bins + 1,
                          @in_progress_count.total_bins
                        )}%
                      </p>
                    <% else %>
                      <p class="mt-1 text-sm font-semibold text-gray-900">None</p>
                      <p class="mt-1 text-xs text-gray-600">Start next scheduled</p>
                    <% end %>
                  </div>

                  <%= if @in_progress_count do %>
                    <.cc_button variant="ghost" phx-click="set_tab" phx-value-tab="in-progress">
                      Open
                    </.cc_button>
                  <% else %>
                    <.cc_button variant="ghost" phx-click="start_next_scheduled">Start</.cc_button>
                  <% end %>
                </div>
              </div>

              <div class="bg-white border border-gray-200 rounded-xl p-4">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-xs font-semibold text-gray-500">Open variances</p>
                    <p class="mt-1 text-sm font-semibold text-gray-900">{@variances_total}</p>
                    <p class="mt-1 text-xs text-gray-600">Investigations: {@open_investigations}</p>
                  </div>

                  <.cc_button variant="ghost" phx-click="set_tab" phx-value-tab="variances">
                    Review
                  </.cc_button>
                </div>
              </div>
            </div>
            
    <!-- Tabs -->
            <div class="border-b border-gray-200 mb-6">
              <nav class="flex space-x-1 overflow-x-auto">
                <.tab_button active={@active_tab == "scheduled"} tab="scheduled" label="Scheduled">
                  <%= if @scheduled_total > 0 do %>
                    <.cc_badge variant="neutral">{@scheduled_total}</.cc_badge>
                  <% end %>
                </.tab_button>

                <.tab_button
                  active={@active_tab == "in-progress"}
                  tab="in-progress"
                  label="In Progress"
                >
                  <%= if @in_progress_total > 0 do %>
                    <.cc_badge variant="warning">{@in_progress_total}</.cc_badge>
                  <% end %>
                </.tab_button>

                <.tab_button active={@active_tab == "completed"} tab="completed" label="Completed">
                  <%= if @completed_total > 0 do %>
                    <.cc_badge variant="neutral">{@completed_total}</.cc_badge>
                  <% end %>
                </.tab_button>

                <.tab_button active={@active_tab == "variances"} tab="variances" label="Variances">
                  <%= if @variances_total > 0 do %>
                    <.cc_badge variant="warning">{@variances_total}</.cc_badge>
                  <% end %>
                </.tab_button>
              </nav>
            </div>
            
    <!-- Scheduled -->
            <%= if @active_tab == "scheduled" do %>
              <.cc_card title="Scheduled Counts">
                <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-4">
                  <div class="w-full sm:max-w-md">
                    <label class="block text-xs font-semibold text-gray-500 mb-1">Filter</label>
                    <form phx-change="set_scheduled_filter">
                      <input
                        type="text"
                        name="scheduled_filter"
                        value={@scheduled_filter}
                        placeholder="Search by ID, location, bins…"
                        class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                      />
                    </form>
                  </div>

                  <div class="flex flex-col sm:flex-row gap-2">
                    <%= if @in_progress_count do %>
                      <.cc_button variant="secondary" phx-click="set_tab" phx-value-tab="in-progress">
                        Resume In Progress
                      </.cc_button>
                    <% end %>

                    <.cc_button phx-click="start_next_scheduled">Start Next</.cc_button>
                  </div>
                </div>

                <div class="space-y-3">
                  <%= if @scheduled_visible == [] do %>
                    <div class="p-4 border border-dashed border-gray-300 rounded-lg bg-gray-50">
                      <p class="text-sm font-semibold text-gray-900">No scheduled counts found</p>
                      <p class="text-xs text-gray-600 mt-1">
                        Try clearing the filter or schedule a new count.
                      </p>
                    </div>
                  <% else %>
                    <%= for count <- @scheduled_visible do %>
                      <div class="p-4 border-2 border-gray-200 rounded-lg hover:border-indigo-300 hover:shadow-md transition-all">
                        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-3">
                          <div class="flex items-center space-x-3">
                            <h3 class="font-semibold text-gray-900">{count.id}</h3>
                            <.cc_badge variant="neutral">{count.status}</.cc_badge>
                          </div>

                          <.cc_button
                            size="sm"
                            phx-click="start_count"
                            phx-value-id={count.id}
                            class="w-full sm:w-auto"
                          >
                            <:left_icon><.cc_icon name="play" class="w-4 h-4" /></:left_icon>
                            Start
                          </.cc_button>
                        </div>

                        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 text-sm">
                          <div>
                            <span class="text-gray-600">Date:</span>
                            <span class="ml-2 font-medium text-gray-900">{count.date}</span>
                          </div>
                          <div>
                            <span class="text-gray-600">Location:</span>
                            <span class="ml-2 text-gray-900">{count.location}</span>
                          </div>
                          <div>
                            <span class="text-gray-600">Bins:</span>
                            <span class="ml-2 text-gray-900">{count.bins}</span>
                          </div>
                          <div>
                            <span class="text-gray-600">SKUs:</span>
                            <span class="ml-2 text-gray-900">{count.skus}</span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </.cc_card>
            <% end %>
            
    <!-- In Progress -->
            <%= if @active_tab == "in-progress" do %>
              <%= if @in_progress_count do %>
                <div class="space-y-6">
                  <.cc_card title={"Cycle Count: " <> @in_progress_count.id}>
                    <div class="mb-6">
                      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-2">
                        <span class="text-sm font-medium text-gray-700">
                          <span class="font-semibold text-gray-900">
                            {@in_progress_count.location}
                          </span>
                          • Bin {@in_progress_count.current_bin} ({@in_progress_count.completed_bins +
                            1}/{@in_progress_count.total_bins})
                        </span>

                        <span class="text-sm font-semibold text-gray-900">
                          {percent(
                            @in_progress_count.completed_bins + 1,
                            @in_progress_count.total_bins
                          )}%
                        </span>
                      </div>

                      <.cc_progress_bar
                        value={@in_progress_count.completed_bins + 1}
                        max={@in_progress_count.total_bins}
                      />

                      <div class="mt-3 flex flex-wrap items-center gap-2 text-xs text-gray-600">
                        <span class="inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 font-semibold">
                          Mismatches: {length(@mismatches)}
                        </span>

                        <.cc_button variant="ghost" phx-click="toggle_variances_only" type="button">
                          {if @show_variances_only, do: "Show all items", else: "Show variances only"}
                        </.cc_button>

                        <.cc_button variant="ghost" phx-click="fill_actuals_expected" type="button">
                          Fill actuals = expected
                        </.cc_button>
                      </div>
                    </div>

                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                      <!-- Count Sheet -->
                      <div>
                        <h3 class="text-sm font-semibold text-gray-900 mb-3">
                          Bin {@in_progress_count.current_bin} Count Sheet
                        </h3>

                        <div class="border rounded-lg overflow-hidden">
                          <table class="w-full text-sm">
                            <thead class="bg-gray-50 border-b">
                              <tr>
                                <th class="text-left py-2 px-3 font-semibold text-gray-700">SKU</th>
                                <th class="text-left py-2 px-3 font-semibold text-gray-700">Lot</th>
                                <th class="text-right py-2 px-3 font-semibold text-gray-700">
                                  Expected
                                </th>
                                <th class="text-right py-2 px-3 font-semibold text-gray-700">
                                  Actual
                                </th>
                                <th class="text-right py-2 px-3 font-semibold text-gray-700">Var</th>
                                <th class="text-center py-2 px-3 font-semibold text-gray-700">
                                  Status
                                </th>
                                <th class="text-right py-2 px-3 font-semibold text-gray-700"></th>
                              </tr>
                            </thead>

                            <tbody class="divide-y divide-gray-100">
                              <%= for {item, idx} <- Enum.with_index(@in_progress_count.items) do %>
                                <%= if !@show_variances_only || item.variance != 0 do %>
                                  <tr class={[item.variance != 0 && "bg-orange-50"]}>
                                    <td class="py-2 px-3 font-medium text-gray-900">{item.sku}</td>
                                    <td class="py-2 px-3 font-mono text-xs text-gray-600">
                                      {item.lot}
                                    </td>
                                    <td class="py-2 px-3 text-right text-gray-900">
                                      {item.expected}u
                                    </td>
                                    <td class="py-2 px-3 text-right">
                                      <input
                                        type="number"
                                        name="actual"
                                        value={item.actual}
                                        phx-change="set_actual"
                                        phx-value-idx={idx}
                                        phx-debounce="200"
                                        class="w-20 text-right text-sm border border-gray-300 rounded-md px-2 py-1 bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                                      />
                                    </td>
                                    <td class="py-2 px-3 text-right">
                                      <span class={[
                                        "font-semibold",
                                        item.variance == 0 && "text-gray-700",
                                        item.variance != 0 && "text-orange-800"
                                      ]}>
                                        {signed(item.variance)}
                                      </span>
                                    </td>
                                    <td class="py-2 px-3 text-center">
                                      <%= if item.variance == 0 do %>
                                        <.cc_icon
                                          name="check_circle"
                                          class="w-4 h-4 text-green-600 inline"
                                        />
                                      <% else %>
                                        <.cc_icon
                                          name="alert_triangle"
                                          class="w-4 h-4 text-orange-600 inline"
                                        />
                                      <% end %>
                                    </td>
                                    <td class="py-2 px-3 text-right">
                                      <%= if item.variance != 0 do %>
                                        <.cc_button
                                          variant="ghost"
                                          phx-click="quick_match"
                                          phx-value-idx={idx}
                                          type="button"
                                        >
                                          Match
                                        </.cc_button>
                                      <% end %>
                                    </td>
                                  </tr>
                                <% end %>
                              <% end %>
                            </tbody>
                          </table>
                        </div>

                        <div class="mt-3 text-xs text-gray-600">
                          Practical flow: adjust Actuals → create investigations for mismatches → record steps → complete.
                        </div>
                      </div>
                      
    <!-- Scanner + alternatives + demo -->
                      <div>
                        <h3 class="text-sm font-semibold text-gray-900 mb-3">📷 Scan to Count</h3>

                        <div class="bg-blue-50 border border-blue-200 rounded-xl p-5">
                          <form phx-change="scan_change" phx-submit="scan_submit" class="space-y-3">
                            <input
                              type="text"
                              name="code"
                              value={@scan_code}
                              placeholder="Scan unit QR code and press Enter…"
                              autofocus
                              class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                            />

                            <div class="flex items-center justify-between gap-2">
                              <.cc_button variant="secondary" size="sm" type="submit">
                                Add Scan
                              </.cc_button>
                              <.cc_button variant="ghost" phx-click="reset_scans" type="button">
                                Reset
                              </.cc_button>
                            </div>
                          </form>
                          
    <!-- More counting options (simple) -->
                          <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <div class="bg-white border border-blue-200 rounded-lg p-3">
                              <p class="text-xs font-semibold text-gray-700 mb-2">Manual adjust</p>
                              <div class="flex flex-wrap gap-2">
                                <.cc_button
                                  variant="secondary"
                                  size="sm"
                                  phx-click="adjust_scans"
                                  phx-value-delta="-1"
                                  type="button"
                                >
                                  -1
                                </.cc_button>
                                <.cc_button
                                  variant="secondary"
                                  size="sm"
                                  phx-click="adjust_scans"
                                  phx-value-delta="1"
                                  type="button"
                                >
                                  +1
                                </.cc_button>
                                <.cc_button
                                  variant="secondary"
                                  size="sm"
                                  phx-click="adjust_scans"
                                  phx-value-delta="5"
                                  type="button"
                                >
                                  +5
                                </.cc_button>
                                <.cc_button
                                  variant="secondary"
                                  size="sm"
                                  phx-click="set_scans_expected"
                                  type="button"
                                >
                                  Set to expected
                                </.cc_button>
                              </div>
                            </div>

                            <div class="bg-white border border-blue-200 rounded-lg p-3">
                              <p class="text-xs font-semibold text-gray-700 mb-2">Add by quantity</p>
                              <form
                                phx-change="add_qty_change"
                                phx-submit="add_qty_submit"
                                class="flex gap-2"
                              >
                                <input
                                  type="number"
                                  name="add_qty"
                                  value={@add_qty}
                                  placeholder="Qty"
                                  class="w-24 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                                />
                                <.cc_button variant="secondary" size="sm" type="submit">
                                  Add
                                </.cc_button>
                              </form>
                              <p class="mt-2 text-xs text-gray-600">
                                Use when counts come from a tally instead of scans.
                              </p>
                            </div>
                          </div>

                          <div class="mt-4">
                            <div class="flex justify-between text-sm mb-2 gap-3">
                              <span class="text-gray-700">
                                Scanned: {@scanned_units} / {@expected_units} expected units
                              </span>
                              <span class="font-semibold text-gray-900">
                                {percent(@scanned_units, @expected_units)}%
                              </span>
                            </div>

                            <.cc_progress_bar value={@scanned_units} max={@expected_units} />

                            <%= if @recent_scans != [] do %>
                              <div class="mt-3">
                                <p class="text-xs font-semibold text-gray-600 mb-1">Recent events</p>
                                <div class="flex flex-wrap gap-2">
                                  <%= for code <- @recent_scans do %>
                                    <span class="inline-flex items-center rounded-full bg-white border border-blue-200 text-blue-900 px-2 py-0.5 text-xs font-semibold">
                                      {code}
                                    </span>
                                  <% end %>
                                </div>
                              </div>
                            <% end %>
                          </div>
                          
    <!-- Demo: how scanning works in practice -->
                          <div class="mt-5 border-t border-blue-200 pt-4">
                            <p class="text-xs font-semibold text-gray-700">Scan demo</p>
                            <p class="mt-1 text-xs text-gray-600">
                              In practice, a handheld scanner types the code into the field and sends Enter.
                              Below buttons simulate that behavior.
                            </p>

                            <div class="mt-3 flex flex-wrap gap-2">
                              <%= for code <- @demo_codes do %>
                                <.cc_button
                                  variant="secondary"
                                  size="sm"
                                  phx-click="demo_scan"
                                  phx-value-code={code}
                                  type="button"
                                >
                                  Scan {code}
                                </.cc_button>
                              <% end %>
                            </div>
                          </div>
                        </div>

                        <%= if @mismatches != [] do %>
                          <div class="mt-6 p-4 bg-orange-50 border border-orange-200 rounded-lg">
                            <div class="flex items-start space-x-3">
                              <.cc_icon
                                name="alert_triangle"
                                class="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5"
                              />

                              <div class="text-sm w-full">
                                <p class="font-semibold text-orange-900 mb-1">Mismatches detected</p>
                                <p class="text-orange-800 text-xs mb-3">
                                  Create investigations for each mismatch to track daily follow-up.
                                </p>

                                <div class="space-y-2">
                                  <%= for v <- @mismatches do %>
                                    <div class="bg-white border border-orange-200 rounded-lg p-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                                      <div>
                                        <p class="text-sm font-semibold text-gray-900">{v.sku}</p>
                                        <p class="text-xs text-gray-600">
                                          Lot: <span class="font-mono">{v.lot}</span>
                                        </p>
                                        <p class="text-xs text-orange-800 mt-1">
                                          Expected: {v.expected} • Actual: {v.actual} • Var: {signed(
                                            v.variance
                                          )}
                                        </p>
                                      </div>

                                      <div class="flex flex-wrap gap-2">
                                        <.cc_button
                                          size="sm"
                                          variant="secondary"
                                          phx-click="create_investigation"
                                          phx-value-sku={v.sku}
                                          phx-value-lot={v.lot}
                                          phx-value-variance={v.variance}
                                          type="button"
                                        >
                                          Create investigation
                                        </.cc_button>

                                        <.cc_button
                                          size="sm"
                                          variant="secondary"
                                          phx-click="adjacent_bins"
                                          type="button"
                                        >
                                          Search adjacent bins
                                        </.cc_button>

                                        <.cc_button
                                          size="sm"
                                          variant="secondary"
                                          phx-click="check_movements"
                                          type="button"
                                        >
                                          Check movements
                                        </.cc_button>

                                        <.cc_button
                                          size="sm"
                                          phx-click="set_tab"
                                          phx-value-tab="variances"
                                          type="button"
                                        >
                                          Open variances
                                        </.cc_button>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>

                    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mt-6 pt-6 border-t border-gray-200">
                      <.cc_button variant="secondary" phx-click="pause_count">Save & Exit</.cc_button>

                      <div class="flex flex-col sm:flex-row gap-3">
                        <.cc_button
                          variant="secondary"
                          phx-click="previous_bin"
                          disabled={@prev_disabled}
                          type="button"
                        >
                          Previous Bin
                        </.cc_button>

                        <.cc_button phx-click="next_bin" disabled={@next_disabled} type="button">
                          {@next_label}
                        </.cc_button>

                        <.cc_button variant="secondary" phx-click="complete_count" type="button">
                          Complete Count
                        </.cc_button>
                      </div>
                    </div>
                  </.cc_card>
                </div>
              <% else %>
                <.cc_card title="No Count In Progress">
                  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                    <div>
                      <p class="text-sm font-semibold text-gray-900">
                        Start the next scheduled count
                      </p>
                      <p class="text-xs text-gray-600 mt-1">
                        Typical flow: Start → adjust Actuals → scan/tally units → investigate variances → Complete.
                      </p>
                    </div>

                    <div class="flex flex-col sm:flex-row gap-2">
                      <.cc_button variant="secondary" phx-click="set_tab" phx-value-tab="scheduled">
                        View Scheduled
                      </.cc_button>
                      <.cc_button phx-click="start_next_scheduled">Start Next</.cc_button>
                    </div>
                  </div>
                </.cc_card>
              <% end %>
            <% end %>
            
    <!-- Completed -->
            <%= if @active_tab == "completed" do %>
              <div class="space-y-4">
                <.cc_card title="Completed Counts">
                  <div class="space-y-3">
                    <%= if @completed_counts == [] do %>
                      <div class="p-4 border border-dashed border-gray-300 rounded-lg bg-gray-50">
                        <p class="text-sm font-semibold text-gray-900">No completed cycle counts</p>
                        <p class="text-xs text-gray-600 mt-1">
                          Completed counts will appear here for audit and review.
                        </p>
                      </div>
                    <% else %>
                      <%= for c <- @completed_counts do %>
                        <div class="p-4 border-2 border-gray-200 rounded-lg">
                          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                            <div>
                              <div class="flex items-center gap-2">
                                <h3 class="font-semibold text-gray-900">{c.id}</h3>
                                <.cc_badge variant="neutral">completed</.cc_badge>

                                <%= if c.summary.variances > 0 do %>
                                  <.cc_badge variant="warning">
                                    {c.summary.variances} variances
                                  </.cc_badge>
                                <% end %>
                              </div>

                              <p class="text-sm text-gray-600 mt-1">
                                {c.date} • {c.location} • {c.bins}
                              </p>

                              <div class="mt-2 flex flex-wrap gap-2 text-xs text-gray-600">
                                <span class="inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 font-semibold">
                                  Items: {c.summary.items}
                                </span>
                                <span class="inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 font-semibold">
                                  Bins: {c.summary.bins}
                                </span>
                                <span class="inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 font-semibold">
                                  Scanned: {c.summary.scanned_units}
                                </span>
                              </div>
                            </div>

                            <div class="flex gap-2">
                              <.cc_button
                                variant="ghost"
                                phx-click="view_completed"
                                phx-value-id={c.id}
                                type="button"
                              >
                                View
                              </.cc_button>
                              <.cc_button
                                variant="ghost"
                                phx-click="export_completed"
                                phx-value-id={c.id}
                                type="button"
                              >
                                Export
                              </.cc_button>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                </.cc_card>

                <%= if @active_completed do %>
                  <.cc_card title={"Completed Details: " <> @active_completed.id} class="bg-gray-50">
                    <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                      <div>
                        <p class="text-sm text-gray-900">
                          <span class="font-semibold">{@active_completed.location}</span>
                          • {@active_completed.date} • {@active_completed.bins}
                        </p>

                        <div class="mt-3 grid grid-cols-1 sm:grid-cols-3 gap-3">
                          <div class="bg-white border border-gray-200 rounded-lg p-3">
                            <p class="text-xs font-semibold text-gray-500">Items</p>
                            <p class="mt-1 text-sm font-semibold text-gray-900">
                              {@active_completed.summary.items}
                            </p>
                          </div>
                          <div class="bg-white border border-gray-200 rounded-lg p-3">
                            <p class="text-xs font-semibold text-gray-500">Bins</p>
                            <p class="mt-1 text-sm font-semibold text-gray-900">
                              {@active_completed.summary.bins}
                            </p>
                          </div>
                          <div class="bg-white border border-gray-200 rounded-lg p-3">
                            <p class="text-xs font-semibold text-gray-500">Variances</p>
                            <p class="mt-1 text-sm font-semibold text-gray-900">
                              {@active_completed.summary.variances}
                            </p>
                          </div>
                        </div>

                        <p class="mt-3 text-xs text-gray-600">
                          This is a simple mock “details” view. In a full app, this would drill into bin-by-bin and item-level audit history.
                        </p>
                      </div>

                      <div class="flex gap-2">
                        <.cc_button
                          variant="secondary"
                          phx-click="close_completed_details"
                          type="button"
                        >
                          Close
                        </.cc_button>
                      </div>
                    </div>
                  </.cc_card>
                <% end %>
              </div>
            <% end %>
            
    <!-- Variances -->
            <%= if @active_tab == "variances" do %>
              <.cc_card title="Variance Investigations">
                <div class="space-y-4">
                  <%= if @mismatches != [] do %>
                    <div class="p-4 border border-orange-200 bg-orange-50 rounded-lg">
                      <div class="flex items-start justify-between gap-4">
                        <div>
                          <p class="text-sm font-semibold text-gray-900">Current count mismatches</p>
                          <p class="text-xs text-gray-600 mt-1">
                            Create an investigation per mismatch, track actions, then close when root cause is confirmed.
                          </p>
                        </div>
                        <.cc_badge variant="warning">{length(@mismatches)}</.cc_badge>
                      </div>

                      <div class="mt-3 space-y-2">
                        <%= for v <- @mismatches do %>
                          <div class="bg-white border border-orange-200 rounded-lg p-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                            <div>
                              <p class="text-sm font-semibold text-gray-900">{v.sku}</p>
                              <p class="text-xs text-gray-600">
                                Lot: <span class="font-mono">{v.lot}</span>
                              </p>
                              <p class="text-xs text-orange-800 mt-1">
                                Expected: {v.expected} • Actual: {v.actual} • Var: {signed(v.variance)}
                              </p>
                            </div>

                            <div class="flex flex-wrap gap-2">
                              <.cc_button
                                size="sm"
                                variant="secondary"
                                phx-click="create_investigation"
                                phx-value-sku={v.sku}
                                phx-value-lot={v.lot}
                                phx-value-variance={v.variance}
                                type="button"
                              >
                                Create investigation
                              </.cc_button>

                              <.cc_button
                                size="sm"
                                variant="secondary"
                                phx-click="adjacent_bins"
                                type="button"
                              >
                                Search adjacent bins
                              </.cc_button>

                              <.cc_button
                                size="sm"
                                variant="secondary"
                                phx-click="check_movements"
                                type="button"
                              >
                                Check movements
                              </.cc_button>

                              <.cc_button
                                size="sm"
                                variant="secondary"
                                phx-click="set_tab"
                                phx-value-tab="in-progress"
                                type="button"
                              >
                                Back to counting
                              </.cc_button>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <div>
                    <div class="flex items-center justify-between">
                      <p class="text-sm font-semibold text-gray-900">Investigations</p>
                      <p class="text-xs text-gray-600">
                        Open: {@open_investigations} • Total: {length(@investigations)}
                      </p>
                    </div>

                    <div class="mt-3 space-y-3">
                      <%= for inv <- @investigations do %>
                        <div class={[
                          "p-4 border-2 rounded-lg",
                          inv.status == "closed" && "border-gray-200 bg-gray-50",
                          inv.status != "closed" && "border-orange-200 bg-orange-50"
                        ]}>
                          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                            <div>
                              <div class="flex items-center gap-2">
                                <h3 class="font-semibold text-gray-900">{inv.id}</h3>
                                <%= if inv.status == "closed" do %>
                                  <.cc_badge variant="neutral">Closed</.cc_badge>
                                <% else %>
                                  <.cc_badge variant="warning">Investigating</.cc_badge>
                                <% end %>
                              </div>

                              <p class="text-sm text-gray-600 mt-1">
                                SKU: {inv.sku} | Lot: <span class="font-mono">{inv.lot}</span>
                                | Variance: {signed(inv.variance)} units
                              </p>

                              <div class="mt-3 space-y-2 text-sm">
                                <%= for {step, idx} <- Enum.with_index(inv.steps) do %>
                                  <div class="flex items-start space-x-2">
                                    <%= if step.status == "done" do %>
                                      <.cc_icon
                                        name="check_circle"
                                        class="w-4 h-4 text-green-600 flex-shrink-0 mt-0.5"
                                      />
                                    <% else %>
                                      <.cc_icon
                                        name="alert_triangle"
                                        class="w-4 h-4 text-orange-600 flex-shrink-0 mt-0.5"
                                      />
                                    <% end %>

                                    <div class="flex-1">
                                      <span class="text-gray-700">{step.text}</span>
                                    </div>

                                    <%= if inv.status != "closed" && step.status != "done" do %>
                                      <.cc_button
                                        variant="ghost"
                                        phx-click="mark_step_done"
                                        phx-value-id={inv.id}
                                        phx-value-idx={idx}
                                        type="button"
                                      >
                                        Mark done
                                      </.cc_button>
                                    <% end %>
                                  </div>
                                <% end %>
                              </div>

                              <%= if inv.notes != [] do %>
                                <div class="mt-3">
                                  <p class="text-xs font-semibold text-gray-700">Notes</p>
                                  <ul class="mt-1 list-disc list-inside text-xs text-gray-700 space-y-1">
                                    <%= for note <- inv.notes do %>
                                      <li>{note}</li>
                                    <% end %>
                                  </ul>
                                </div>
                              <% end %>

                              <%= if @note_for == inv.id do %>
                                <div class="mt-3">
                                  <form
                                    phx-change="note_change"
                                    phx-submit="save_note"
                                    class="space-y-2"
                                  >
                                    <textarea
                                      name="note"
                                      rows="3"
                                      class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                                      placeholder="Add a note (root cause, action taken, who verified, etc.)"
                                    ><%= @note_draft %></textarea>

                                    <div class="flex gap-2">
                                      <.cc_button variant="secondary" size="sm" type="submit">
                                        Save note
                                      </.cc_button>
                                      <.cc_button
                                        variant="ghost"
                                        phx-click="cancel_note"
                                        type="button"
                                      >
                                        Cancel
                                      </.cc_button>
                                    </div>
                                  </form>
                                </div>
                              <% end %>
                            </div>

                            <div class="flex flex-wrap gap-2">
                              <%= if inv.status != "closed" && @note_for != inv.id do %>
                                <.cc_button
                                  size="sm"
                                  variant="secondary"
                                  phx-click="open_note"
                                  phx-value-id={inv.id}
                                  type="button"
                                >
                                  Add note
                                </.cc_button>
                              <% end %>

                              <%= if inv.status != "closed" do %>
                                <.cc_button
                                  size="sm"
                                  phx-click="close_investigation"
                                  phx-value-id={inv.id}
                                  type="button"
                                >
                                  Close
                                </.cc_button>
                              <% end %>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div class="p-4 border border-gray-200 rounded-lg bg-white">
                    <p class="text-sm font-semibold text-gray-900">Daily reminder</p>
                    <p class="text-xs text-gray-600 mt-1">
                      Close investigations once root cause is confirmed (move, pick, damage/scrap), and ensure corrective action is recorded.
                    </p>
                  </div>
                </div>
              </.cc_card>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end

  # --------------------
  # Flow transition helper
  # --------------------

  defp start_from_scheduled(socket, scheduled) do
    ic =
      normalize_in_progress(%{
        id: scheduled.id,
        location: scheduled.location,
        bins: scheduled.bins,
        started_date: scheduled.date,
        current_bin: first_bin_from_range(scheduled.bins) || "A-10",
        total_bins: 6,
        completed_bins: 0,
        items: [
          %{
            sku: "LZ-500",
            lot: "LOT-089",
            expected: 23,
            actual: 23,
            variance: 0,
            status: "match"
          },
          %{
            sku: "SSB-200",
            lot: "LOT-087",
            expected: 15,
            actual: 12,
            variance: -3,
            status: "short"
          },
          %{sku: "STD-300", lot: "LOT-090", expected: 8, actual: 8, variance: 0, status: "match"},
          %{sku: "GJ-206", lot: "LOT-088", expected: 12, actual: 12, variance: 0, status: "match"}
        ]
      })

    scheduled_counts = Enum.reject(socket.assigns.scheduled_counts, &(&1.id == scheduled.id))

    socket =
      socket
      |> assign(:in_progress_count, ic)
      |> assign(:scheduled_counts, scheduled_counts)
      |> assign(:active_tab, "in-progress")
      |> assign(:scanned_units, 0)
      |> assign(:recent_scans, [])
      |> assign(:scan_code, "")
      |> assign(:add_qty, "")
      |> assign(:show_variances_only, false)
      |> toast(:success, "Started #{scheduled.id}. You can scan, tally, or update actuals.")

    {:noreply, socket}
  end

  # --------------------
  # Pure helpers
  # --------------------

  defp toast(socket, kind, msg), do: assign(socket, :toast, %{kind: kind, msg: msg})

  defp next_scheduled([]), do: nil
  defp next_scheduled(counts), do: counts |> Enum.sort_by(& &1.date) |> List.first()

  defp filter_scheduled(counts, filter) do
    f = String.downcase(String.trim(filter || ""))

    if f == "" do
      counts
    else
      Enum.filter(counts, fn c ->
        hay =
          [c.id, c.date, c.location, c.bins, c.skus]
          |> Enum.join(" ")
          |> String.downcase()

        String.contains?(hay, f)
      end)
    end
  end

  defp normalize_in_progress(ic) do
    items = Enum.map(ic.items, &recalc_item/1)
    %{ic | items: items}
  end

  defp recalc_item(item) do
    expected = parse_int(item.expected, 0)
    actual = parse_int(item.actual, 0)
    variance = actual - expected

    status =
      cond do
        variance == 0 -> "match"
        variance < 0 -> "short"
        true -> "over"
      end

    item
    |> Map.put(:expected, expected)
    |> Map.put(:actual, actual)
    |> Map.put(:variance, variance)
    |> Map.put(:status, status)
  end

  defp apply_scan(socket, code, source) do
    new_scanned = min(socket.assigns.scanned_units + 1, socket.assigns.expected_units)

    tag =
      case source do
        :demo -> "DEMO:#{code}"
        _ -> code
      end

    recent =
      [tag | socket.assigns.recent_scans]
      |> Enum.take(5)

    socket
    |> assign(:scanned_units, new_scanned)
    |> assign(:recent_scans, recent)
    |> assign(:scan_code, "")
    |> toast(:success, "Scanned #{code}.")
  end

  defp percent(_num, 0), do: 0

  defp percent(num, denom) when is_integer(num) and is_integer(denom) and denom > 0,
    do: round(num * 100 / denom)

  defp signed(n) when is_integer(n) and n > 0, do: "+" <> Integer.to_string(n)
  defp signed(n) when is_integer(n), do: Integer.to_string(n)

  defp parse_int(nil, default), do: default
  defp parse_int(v, default) when is_integer(v), do: v

  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp first_bin_from_range(bins) when is_binary(bins) do
    case Regex.run(~r/^([A-Za-z]+-\d+)/, bins, capture: :all_but_first) do
      [bin] -> bin
      _ -> nil
    end
  end

  defp bin_shift(bin, delta) when is_integer(delta) do
    {prefix, n} = parse_bin(bin)
    prefix <> "-" <> pad2(max(n + delta, 0))
  end

  defp parse_bin(bin) when is_binary(bin) do
    case Regex.run(~r/^([A-Za-z]+)-(\d+)$/, bin, capture: :all_but_first) do
      [prefix, num] -> {prefix, parse_int(num, 0)}
      _ -> {"A", 0}
    end
  end

  defp pad2(n) when is_integer(n) and n < 10, do: "0" <> Integer.to_string(n)
  defp pad2(n) when is_integer(n), do: Integer.to_string(n)

  defp clamp(v, min_v, max_v) when v < min_v, do: min_v
  defp clamp(v, min_v, max_v) when v > max_v, do: max_v
  defp clamp(v, _min_v, _max_v), do: v

  # --------------------
  # Function components (prefixed to avoid conflicts)
  # --------------------

  attr :active, :boolean, required: true
  attr :tab, :string, required: true
  attr :label, :string, required: true
  slot :inner_block

  def tab_button(assigns) do
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
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def cc_card(assigns) do
    ~H"""
    <div class={["bg-white border border-gray-200 rounded-xl p-5", @class]}>
      <%= if @title do %>
        <div class="mb-4">
          <h2 class="text-sm font-semibold text-gray-900">{@title}</h2>
        </div>
      <% end %>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :variant, :string, default: "neutral", values: ["neutral", "warning"]
  slot :inner_block, required: true

  def cc_badge(assigns) do
    classes =
      case assigns.variant do
        "warning" ->
          "inline-flex items-center rounded-full bg-orange-100 text-orange-800 px-2 py-0.5 text-xs font-semibold"

        _ ->
          "inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 text-xs font-semibold"
      end

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <span class={@classes}>{render_slot(@inner_block)}</span>
    """
  end

  attr :value, :integer, required: true
  attr :max, :integer, required: true

  def cc_progress_bar(assigns) do
    pct =
      cond do
        assigns.max <= 0 -> 0
        assigns.value <= 0 -> 0
        assigns.value >= assigns.max -> 100
        true -> round(assigns.value * 100 / assigns.max)
      end

    assigns = assign(assigns, :pct, pct)

    ~H"""
    <div class="w-full h-2 rounded-full bg-gray-200 overflow-hidden">
      <div class="h-2 rounded-full bg-[#2E7D32]" style={"width: #{@pct}%"}></div>
    </div>
    """
  end

  attr :variant, :string, default: "primary", values: ["primary", "secondary", "ghost"]
  attr :size, :string, default: "md", values: ["md", "sm"]
  attr :type, :string, default: "button"
  attr :class, :string, default: nil

  attr :rest, :global, include: ~w(
      disabled form name value
      phx-click phx-change phx-submit phx-debounce
      phx-value-id phx-value-tab phx-value-idx
      phx-value-code phx-value-delta phx-value-sku phx-value-lot phx-value-variance
    )

  slot :left_icon
  slot :inner_block, required: true

  def cc_button(assigns) do
    base =
      "inline-flex items-center justify-center gap-2 font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#2E7D32] disabled:opacity-50 disabled:pointer-events-none"

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 rounded-full hover:bg-gray-200"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg"
        _ -> "bg-[#2E7D32] text-white rounded-full hover:brightness-95"
      end

    size =
      case assigns.size do
        "sm" ->
          case assigns.variant do
            "ghost" -> "px-2 py-1 text-sm"
            _ -> "h-8 px-3 text-xs"
          end

        _ ->
          case assigns.variant do
            "ghost" -> "px-2 py-1 text-sm"
            _ -> "h-9 px-4 text-sm"
          end
      end

    assigns = assign(assigns, :btn_class, [base, variant, size, assigns.class])

    ~H"""
    <button type={@type} class={@btn_class} {@rest}>
      <%= if @left_icon != [] do %>
        <span class="inline-flex items-center">{render_slot(@left_icon)}</span>
      <% end %>
      <span>{render_slot(@inner_block)}</span>
    </button>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "w-4 h-4"

  def cc_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "clipboard_list" -> %>
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
            d="M9 5h6m-6 0a2 2 0 0 0-2 2v1h10V7a2 2 0 0 0-2-2m-6 0a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2"
          />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M7 8v12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2V8"
          />
          <path stroke-linecap="round" stroke-linejoin="round" d="M10 12h6M10 16h6" />
        </svg>
      <% "plus" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 5v14M5 12h14" />
        </svg>
      <% "play" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M8 5l12 7-12 7V5z" />
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
      <% "file_text" -> %>
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
            d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"
          />
          <path stroke-linecap="round" stroke-linejoin="round" d="M14 2v6h6" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M8 13h8M8 17h6" />
        </svg>
      <% "search" -> %>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class={@class}
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-4.35-4.35" />
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M10.5 18a7.5 7.5 0 1 1 0-15 7.5 7.5 0 0 1 0 15z"
          />
        </svg>
      <% _ -> %>
        <span class={@class} aria-hidden="true"></span>
    <% end %>
    """
  end
end
