defmodule AvoflowWeb.AdjustmentsLive do
  use AvoflowWeb, :live_view

  @tabs [
    %{"id" => "pending", "label" => "Pending Approvals"},
    %{"id" => "my-requests", "label" => "My Requests"},
    %{"id" => "history", "label" => "History"},
    %{"id" => "new", "label" => "New Adjustment"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {pending_approvals, my_requests, history} = mock_data()

    socket =
      socket
      |> allow_upload(:new_attachments,
        accept: ~w(.jpg .jpeg .png .pdf),
        max_entries: 6,
        max_file_size: 10_000_000
      )
      |> assign(:q, "")
      |> assign(:unread_count, 3)
      |> assign(:user_label, "Warehouse Ops")
      |> assign(:tabs, @tabs)
      |> assign(:active_tab, "pending")
      |> assign(:pending_approvals, pending_approvals)
      |> assign(:my_requests, my_requests)
      |> assign(:history, history)
      |> assign(:history_search, "")
      |> assign(:history_status, "all")
      |> assign(:history_days, "30")
      |> assign(:history_page, 1)
      |> assign(:history_page_size, 8)
      |> assign(:history_filtered, [])
      |> assign(:history_total, 0)
      |> assign(:selected_adjustment, nil)
      |> assign(:supervisor_notes, "")
      |> assign(:audit_by_id, %{})
      |> assign(:new_adjustment, %{
        "sku" => "",
        "lot" => "",
        "location" => "",
        "bin" => "",
        "quantity" => "",
        "reason" => "",
        "notes" => ""
      })
      |> assign(:new_errors, %{})
      |> assign(:adj_seq, 11)
      |> assign(:stock_by_sku_lot, mock_stock())
      |> compute_stats()
      |> apply_history_filters()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) when socket.assigns.live_action == :show do
    case find_in_pending(socket.assigns.pending_approvals, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Pending adjustment not found: #{id}")}

      adj ->
        socket =
          socket
          |> assign(:selected_adjustment, adj)
          |> assign(:supervisor_notes, "")
          |> log_audit(id, "opened", "Opened review drawer.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :selected_adjustment, nil)}
  end

  @impl true
  def render(assigns) do
    info = Phoenix.Flash.get(assigns.flash, :info)
    error = Phoenix.Flash.get(assigns.flash, :error)

    assigns =
      assigns
      |> assign(:info_flash, info)
      |> assign(:error_flash, error)

    ~H"""
    <div class="">
      <main class="">
        <div class="">
          <%= if @info_flash do %>
            <div class="mb-5 rounded-2xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-900">
              {@info_flash}
            </div>
          <% end %>

          <%= if @error_flash do %>
            <div class="mb-5 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900">
              {@error_flash}
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

            <div class="flex items-start gap-3">
              <div class="mt-0.5 flex h-10 w-10 items-center justify-center rounded-xl bg-gray-900">
                <.adj_icon name="file_edit" class="h-5 w-5 text-white" />
              </div>
              <div class="min-w-0">
                <h1 class="text-2xl font-bold text-gray-900">Adjustments & Approvals</h1>
                <p class="mt-1 text-sm text-gray-600">
                  Request and approve stock adjustments with a clear audit trail (demo data).
                </p>
              </div>
            </div>
          </div>
          
    <!-- Stats -->
          <div class="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <.adj_stat_card label="Pending" value={to_string(@stats.pending)} icon="clock" />
            <.adj_stat_card
              label="Approved (7d)"
              value={to_string(@stats.approved_7d)}
              icon="check_circle"
            />
            <.adj_stat_card label="Net Change (7d)" value={@stats.net_change_7d} icon="trending_down" />
            <.adj_stat_card label="Avg Approval Time" value={@stats.avg_approval_time} icon="clock" />
          </div>
          
    <!-- Tabs -->
          <div class="mb-6 border-b border-gray-200">
            <nav class="flex flex-wrap gap-1">
              <%= for tab <- @tabs do %>
                <button
                  type="button"
                  phx-click="set_tab"
                  phx-value-tab={tab["id"]}
                  class={[
                    "flex items-center gap-2 px-4 py-3 text-sm font-semibold border-b-2 -mb-px transition",
                    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 rounded-t-lg",
                    if(@active_tab == tab["id"],
                      do: "border-[#2E7D32] text-[#2E7D32]",
                      else:
                        "border-transparent text-gray-600 hover:text-gray-900 hover:border-gray-300"
                    )
                  ]}
                >
                  <span>{tab["label"]}</span>
                  <%= if tab["id"] == "pending" do %>
                    <.adj_badge variant="danger">{@stats.pending}</.adj_badge>
                  <% end %>
                  <%= if tab["id"] == "my-requests" do %>
                    <%= if @stats.my_pending > 0 do %>
                      <.adj_badge variant="warning">{@stats.my_pending}</.adj_badge>
                    <% end %>
                  <% end %>
                </button>
              <% end %>
            </nav>
          </div>
          
    <!-- Content -->
          <div class="min-h-[420px]">
            <%= if @active_tab == "pending" do %>
              <.adj_section title="Pending Approvals">
                <div class="space-y-3">
                  <%= for adj <- @pending_approvals do %>
                    <div class="w-full rounded-2xl border border-gray-200 bg-white p-4 hover:bg-gray-50 transition">
                      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                        <div class="min-w-0">
                          <div class="flex flex-wrap items-center gap-2">
                            <span class="text-sm font-semibold text-gray-900">{adj.id}</span>

                            <.adj_badge variant={if(adj.qty < 0, do: "danger", else: "success")}>
                              {qty_label(adj.qty)}
                            </.adj_badge>

                            <.adj_risk_badge level={adj.risk_level} />
                            <.adj_badge variant="neutral">{adj.reason}</.adj_badge>
                          </div>

                          <div class="mt-2 grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm text-gray-700">
                            <div>
                              <span class="text-gray-500">Requested By:</span>
                              <span class="ml-2 font-medium">{adj.requested_by}</span>
                            </div>

                            <div>
                              <span class="text-gray-500">Time:</span>
                              <span class="ml-2">{adj.timestamp}</span>
                            </div>

                            <div class="sm:col-span-2">
                              <span class="text-gray-500">SKU / Lot:</span>
                              <span class="ml-2 font-medium">{adj.sku}</span>
                              <span class="ml-2 font-mono text-xs text-gray-600">{adj.lot}</span>
                            </div>
                          </div>

                          <%= if adj.attachments != [] do %>
                            <div class="mt-2 text-xs text-gray-500">
                              {length(adj.attachments)} attachment(s) provided
                            </div>
                          <% end %>
                        </div>

                        <div class="shrink-0 flex flex-col sm:flex-row gap-2">
                          <.adj_link_button
                            variant="secondary"
                            navigate={~p"/finished-goods/adjustments/#{adj.id}"}
                          >
                            Review
                          </.adj_link_button>

                          <.adj_button
                            variant="primary"
                            phx-click="approve_pending"
                            phx-value-id={adj.id}
                          >
                            Approve
                          </.adj_button>

                          <.adj_button variant="danger" phx-click="deny_pending" phx-value-id={adj.id}>
                            Deny
                          </.adj_button>
                        </div>
                      </div>

                      <div class="mt-3 rounded-xl border border-gray-200 bg-gray-50 p-3 text-sm text-gray-800">
                        {adj.notes}
                      </div>
                    </div>
                  <% end %>

                  <%= if @pending_approvals == [] do %>
                    <div class="rounded-2xl border border-gray-200 bg-gray-50 p-8 text-center">
                      <p class="text-sm font-semibold text-gray-900">No pending approvals</p>
                      <p class="mt-1 text-sm text-gray-600">Queue is clear (demo).</p>
                    </div>
                  <% end %>
                </div>
              </.adj_section>
            <% end %>

            <%= if @active_tab == "my-requests" do %>
              <.adj_section title="My Adjustment Requests">
                <div class="space-y-3">
                  <%= for adj <- @my_requests do %>
                    <div class="rounded-2xl border border-gray-200 bg-white p-4 hover:bg-gray-50 transition">
                      <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                        <div class="min-w-0">
                          <div class="flex flex-wrap items-center gap-2">
                            <span class="text-sm font-semibold text-gray-900">{adj.id}</span>

                            <.adj_badge variant={if(adj.qty < 0, do: "danger", else: "success")}>
                              {qty_label(adj.qty)}
                            </.adj_badge>

                            <.adj_status_badge status={adj.status} />
                          </div>

                          <div class="mt-2 grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm text-gray-700">
                            <div>
                              <span class="text-gray-500">Submitted:</span>
                              <span class="ml-2">{adj.timestamp}</span>
                            </div>
                            <div>
                              <span class="text-gray-500">SKU:</span>
                              <span class="ml-2 font-medium">{adj.sku}</span>
                            </div>
                            <div>
                              <span class="text-gray-500">Lot:</span>
                              <span class="ml-2 font-mono text-xs text-gray-700">{adj.lot}</span>
                            </div>
                            <div>
                              <span class="text-gray-500">Reason:</span>
                              <span class="ml-2 font-semibold text-gray-900">{adj.reason}</span>
                            </div>
                          </div>
                        </div>
                      </div>

                      <div class="mt-3 rounded-xl border border-gray-200 bg-gray-50 p-3 text-sm text-gray-800">
                        {adj.notes}
                      </div>

                      <%= if adj.status == "denied" and Map.get(adj, :denial_reason) do %>
                        <div class="mt-3 rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-900">
                          <p class="font-semibold">Denial Reason</p>
                          <p class="mt-1 text-sm text-red-800">{adj.denial_reason}</p>
                        </div>
                      <% end %>

                      <%= if adj.status == "approved" do %>
                        <div class="mt-3 text-xs text-gray-600">
                          Approved by
                          <span class="font-semibold text-gray-900">{adj.approved_by}</span>
                          at <span class="font-semibold text-gray-900">{adj.approved_at}</span>
                        </div>
                      <% end %>

                      <%= if adj.status == "pending" do %>
                        <div class="mt-3 text-xs text-gray-600">
                          Pending supervisor approval.
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </.adj_section>
            <% end %>

            <%= if @active_tab == "history" do %>
              <.adj_section title="Adjustment History">
                <form
                  phx-change="history_filter"
                  class="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center"
                >
                  <div class="flex-1">
                    <label class="sr-only">Search</label>
                    <input
                      name="search"
                      value={@history_search}
                      placeholder="Search by ID, SKU, or user..."
                      class="w-full rounded-xl border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                    />
                  </div>

                  <div class="grid grid-cols-2 gap-2 sm:flex sm:gap-2">
                    <select
                      name="status"
                      class="w-full rounded-xl border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                    >
                      <option value="all" selected={@history_status == "all"}>All Status</option>
                      <option value="approved" selected={@history_status == "approved"}>
                        Approved Only
                      </option>
                      <option value="denied" selected={@history_status == "denied"}>
                        Denied Only
                      </option>
                    </select>

                    <select
                      name="days"
                      class="w-full rounded-xl border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                    >
                      <option value="7" selected={@history_days == "7"}>Last 7 days</option>
                      <option value="30" selected={@history_days == "30"}>Last 30 days</option>
                      <option value="90" selected={@history_days == "90"}>Last 90 days</option>
                    </select>
                  </div>
                </form>

                <div class="rounded-2xl border border-gray-200 bg-white overflow-hidden">
                  <div class="overflow-x-auto">
                    <table class="w-full text-sm">
                      <thead class="bg-gray-50 border-b border-gray-200">
                        <tr>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            ID
                          </th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            Date
                          </th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            User
                          </th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            SKU
                          </th>
                          <th class="text-right py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            Qty
                          </th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            Reason
                          </th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            Status
                          </th>
                          <th class="text-left py-3 px-4 font-semibold text-gray-700 whitespace-nowrap">
                            Approved By
                          </th>
                        </tr>
                      </thead>
                      <tbody class="divide-y divide-gray-100">
                        <%= for adj <- @history_filtered do %>
                          <tr class="hover:bg-gray-50">
                            <td class="py-3 px-4 font-semibold text-gray-900 whitespace-nowrap">
                              {adj.id}
                            </td>
                            <td class="py-3 px-4 text-gray-600 text-xs whitespace-nowrap">
                              {adj.timestamp}
                            </td>
                            <td class="py-3 px-4 text-gray-700 whitespace-nowrap">
                              {adj.requested_by}
                            </td>
                            <td class="py-3 px-4 font-semibold text-gray-900 whitespace-nowrap">
                              {adj.sku}
                            </td>
                            <td class="py-3 px-4 text-right whitespace-nowrap">
                              <span class={
                                if(adj.qty < 0,
                                  do: "text-red-600 font-semibold",
                                  else: "text-green-700 font-semibold"
                                )
                              }>
                                {qty_compact(adj.qty)}
                              </span>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                              <.adj_badge variant="neutral">{adj.reason}</.adj_badge>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                              <.adj_status_badge status={adj.status} />
                            </td>
                            <td class="py-3 px-4 text-gray-700 whitespace-nowrap">
                              {Map.get(adj, :approved_by, "—")}
                            </td>
                          </tr>
                        <% end %>

                        <%= if @history_total == 0 do %>
                          <tr>
                            <td colspan="8" class="py-10 px-4 text-center text-sm text-gray-600">
                              No matching history records.
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>

                  <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between border-t border-gray-200 px-4 py-3 text-sm text-gray-600">
                    <span>
                      Showing {history_showing_label(
                        @history_page,
                        @history_page_size,
                        @history_total
                      )}
                    </span>

                    <div class="flex gap-2">
                      <.adj_button
                        variant="secondary"
                        phx-click="history_prev"
                        disabled={@history_page <= 1}
                      >
                        Previous
                      </.adj_button>
                      <.adj_button
                        variant="secondary"
                        phx-click="history_next"
                        disabled={@history_page * @history_page_size >= @history_total}
                      >
                        Next
                      </.adj_button>
                    </div>
                  </div>
                </div>
              </.adj_section>
            <% end %>

            <%= if @active_tab == "new" do %>
              <.adj_section title="New Stock Adjustment">
                <div class="mb-4 rounded-2xl border border-gray-200 bg-gray-50 p-4">
                  <div class="flex items-start gap-3">
                    <.adj_icon name="alert_circle" class="h-5 w-5 text-gray-700 mt-0.5" />
                    <div class="text-sm text-gray-800">
                      <p class="font-semibold text-gray-900">Adjustment Approval Required</p>
                      <p class="mt-1 text-sm text-gray-700">
                        Adjustments above ±5 units require supervisor approval. All actions are logged (demo).
                      </p>
                    </div>
                  </div>
                </div>

                <form phx-change="new_change" phx-submit="new_submit" class="space-y-5">
                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <.adj_select
                      label="SKU"
                      name="sku"
                      value={@new_adjustment["sku"]}
                      options={mock_sku_options()}
                      error={Map.get(@new_errors, "sku")}
                    />

                    <.adj_select
                      label="Lot"
                      name="lot"
                      value={@new_adjustment["lot"]}
                      options={mock_lot_options(@new_adjustment["sku"])}
                      error={Map.get(@new_errors, "lot")}
                    />
                  </div>

                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <.adj_select
                      label="Location"
                      name="location"
                      value={@new_adjustment["location"]}
                      options={mock_location_options()}
                      error={Map.get(@new_errors, "location")}
                    />

                    <.adj_input
                      label="Bin"
                      name="bin"
                      value={@new_adjustment["bin"]}
                      placeholder="e.g., A-12"
                      error={Map.get(@new_errors, "bin")}
                    />
                  </div>

                  <%= if @new_adjustment["sku"] != "" and @new_adjustment["lot"] != "" do %>
                    <div class="rounded-2xl border border-gray-200 bg-white p-4">
                      <p class="text-sm text-gray-700">
                        <span class="font-semibold text-gray-900">Current Stock:</span>
                        {stock_label(
                          @stock_by_sku_lot,
                          @new_adjustment["sku"],
                          @new_adjustment["lot"]
                        )}
                      </p>
                    </div>
                  <% end %>

                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <.adj_input
                      label="Adjustment Quantity"
                      name="quantity"
                      type="number"
                      value={@new_adjustment["quantity"]}
                      placeholder="Use negative for decrease (e.g., -3)"
                      helper="Negative = decrease, Positive = increase"
                      error={Map.get(@new_errors, "quantity")}
                    />

                    <.adj_select
                      label="Reason Code"
                      name="reason"
                      value={@new_adjustment["reason"]}
                      options={mock_reason_options()}
                      error={Map.get(@new_errors, "reason")}
                    />
                  </div>

                  <.adj_textarea
                    label="Detailed Notes (required)"
                    name="notes"
                    value={@new_adjustment["notes"]}
                    placeholder="Provide detailed explanation for this adjustment..."
                    rows="4"
                    error={Map.get(@new_errors, "notes")}
                  />
                  
    <!-- Uploads -->
                  <div
                    class="rounded-2xl border border-gray-200 bg-gray-50 p-4"
                    phx-drop-target={@uploads.new_attachments.ref}
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <p class="text-sm font-semibold text-gray-900">Attachments</p>
                        <p class="mt-1 text-xs text-gray-600">
                          Optional (PNG/JPG/PDF up to 10MB). Drag & drop supported.
                        </p>
                      </div>
                      <div class="shrink-0">
                        <label class="inline-flex cursor-pointer items-center gap-2 rounded-full bg-gray-100 px-4 py-2 text-sm font-semibold text-gray-900 hover:bg-gray-200 focus-within:ring-2 focus-within:ring-[#2E7D32] focus-within:ring-offset-2">
                          <.adj_icon name="upload" class="h-4 w-4 text-gray-700" />
                          <span>Choose files</span>
                          <.live_file_input upload={@uploads.new_attachments} class="sr-only" />
                        </label>
                      </div>
                    </div>

                    <%= if @uploads.new_attachments.entries != [] do %>
                      <div class="mt-3 space-y-2">
                        <%= for entry <- @uploads.new_attachments.entries do %>
                          <div class="flex items-center justify-between rounded-xl border border-gray-200 bg-white px-3 py-2">
                            <div class="min-w-0">
                              <p class="truncate text-sm font-medium text-gray-900">
                                {entry.client_name}
                              </p>
                              <p class="text-xs text-gray-600">
                                {round(entry.client_size / 1024)} KB
                              </p>
                            </div>
                            <button
                              type="button"
                              phx-click="remove_upload"
                              phx-value-ref={entry.ref}
                              class="rounded-lg px-2 py-1 text-sm font-semibold text-gray-600 hover:bg-gray-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                            >
                              Remove
                            </button>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <%= if abs(safe_int(@new_adjustment["quantity"], 0)) > 5 do %>
                    <div class="rounded-2xl border border-orange-200 bg-orange-50 p-4">
                      <div class="flex items-start gap-3">
                        <.adj_icon name="alert_circle" class="h-5 w-5 text-orange-700 mt-0.5" />
                        <div class="text-sm text-orange-900">
                          <p class="font-semibold">Supervisor approval required</p>
                          <p class="mt-1 text-sm text-orange-800">
                            Threshold is ±5 units. This request will be routed to pending approvals (demo).
                          </p>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <div class="flex flex-col-reverse gap-2 pt-2 sm:flex-row sm:justify-end sm:gap-3">
                    <.adj_button variant="secondary" type="button" phx-click="new_reset">
                      Cancel
                    </.adj_button>

                    <.adj_button variant="primary" type="submit">
                      Submit for Approval
                    </.adj_button>
                  </div>
                </form>
              </.adj_section>
            <% end %>
          </div>
        </div>
      </main>
    </div>

    <!-- Drawer (pending review) -->
    <%= if @selected_adjustment do %>
      <div
        class="fixed inset-0 z-40 bg-black/40"
        phx-click="close_drawer"
        phx-window-keydown="close_drawer"
        phx-key="escape"
      />

      <div class="fixed inset-y-0 right-0 z-50 w-full max-w-2xl bg-white shadow-2xl">
        <div class="flex h-full flex-col">
          <div class="border-b border-gray-200 px-5 py-4">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-xs font-semibold text-gray-500">Review Adjustment</p>
                <h2 class="mt-1 truncate text-lg font-bold text-gray-900">
                  {@selected_adjustment.id}
                </h2>
                <p class="mt-1 text-sm text-gray-600">
                  Requested by
                  <span class="font-semibold text-gray-900">{@selected_adjustment.requested_by}</span>
                  at <span class="font-semibold text-gray-900">{@selected_adjustment.timestamp}</span>
                </p>
              </div>

              <button
                type="button"
                phx-click="close_drawer"
                class="rounded-lg px-2 py-1 text-sm font-semibold text-gray-600 hover:bg-gray-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
              >
                ✕
              </button>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto px-5 py-5 pb-24">
            <div class="space-y-4">
              <.adj_panel title="Request Details">
                <div class="space-y-2 text-sm">
                  <.adj_kv label="SKU" value={@selected_adjustment.sku} />
                  <.adj_kv label="Lot" value={@selected_adjustment.lot} mono />
                  <.adj_kv label="Quantity" value={qty_label(@selected_adjustment.qty)} />
                  <div class="flex items-center justify-between">
                    <span class="text-gray-500">Reason</span>
                    <.adj_badge variant="neutral">{@selected_adjustment.reason}</.adj_badge>
                  </div>
                </div>
              </.adj_panel>

              <.adj_panel title="Evidence">
                <div class="space-y-3">
                  <div class="rounded-xl border border-gray-200 bg-gray-50 p-3 text-sm text-gray-800">
                    {@selected_adjustment.notes}
                  </div>

                  <%= if @selected_adjustment.attachments != [] do %>
                    <div class="space-y-2">
                      <p class="text-xs font-semibold text-gray-700">Attachments</p>
                      <%= for file <- @selected_adjustment.attachments do %>
                        <div class="flex items-center justify-between rounded-xl border border-gray-200 bg-white px-3 py-2">
                          <div class="flex items-center gap-2 min-w-0">
                            <.adj_icon name="image" class="h-4 w-4 text-gray-500" />
                            <span class="truncate text-sm text-gray-800">{file}</span>
                          </div>
                          <button
                            type="button"
                            phx-click="noop_view_attachment"
                            class="rounded-lg px-2 py-1 text-sm font-semibold text-gray-600 hover:bg-gray-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                          >
                            View
                          </button>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <p class="text-sm text-gray-600">No attachments provided.</p>
                  <% end %>
                </div>
              </.adj_panel>

              <.adj_panel title="Risk Assessment">
                <div class="space-y-2 text-sm">
                  <.adj_kv
                    label="Adjustment Type"
                    value={
                      if(@selected_adjustment.qty < 0,
                        do: "Negative (decrease)",
                        else: "Positive (increase)"
                      )
                    }
                  />
                  <.adj_kv
                    label="Threshold"
                    value={"#{abs(@selected_adjustment.qty)} units (#{if(abs(@selected_adjustment.qty) <= 5, do: "below", else: "above")} ±5)"}
                  />
                  <div class="flex items-center justify-between pt-2 border-t border-gray-200">
                    <span class="font-semibold text-gray-900">Risk Level</span>
                    <.adj_risk_badge level={@selected_adjustment.risk_level} />
                  </div>
                </div>
              </.adj_panel>

              <.adj_panel title="Supervisor Decision">
                <form phx-change="supervisor_notes_change" class="space-y-3">
                  <label class="block text-sm font-semibold text-gray-900">
                    Supervisor notes (optional)
                  </label>
                  <textarea
                    name="supervisor_notes"
                    rows="3"
                    class="w-full rounded-xl border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                  ><%= @supervisor_notes %></textarea>
                </form>

                <div class="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <.adj_button
                    variant="danger"
                    phx-click="deny_pending"
                    phx-value-id={@selected_adjustment.id}
                  >
                    ✕ Deny & Record
                  </.adj_button>

                  <.adj_button
                    variant="primary"
                    phx-click="approve_pending"
                    phx-value-id={@selected_adjustment.id}
                  >
                    ✓ Approve & Record
                  </.adj_button>
                </div>

                <p class="mt-3 text-xs text-gray-600">
                  Decision will create a signed stock movement event and append to the audit log (demo).
                </p>
              </.adj_panel>

              <.adj_panel title="Audit Trail">
                <%= for evt <- Map.get(@audit_by_id, @selected_adjustment.id, []) do %>
                  <div class="flex items-start justify-between gap-3 rounded-xl border border-gray-200 bg-white px-3 py-2">
                    <div class="min-w-0">
                      <p class="text-sm font-semibold text-gray-900">{evt.action}</p>
                      <p class="mt-0.5 text-xs text-gray-600">{evt.message}</p>
                    </div>
                    <div class="shrink-0 text-xs text-gray-500">{evt.at}</div>
                  </div>
                <% end %>

                <%= if Map.get(@audit_by_id, @selected_adjustment.id, []) == [] do %>
                  <p class="text-sm text-gray-600">No audit events recorded yet.</p>
                <% end %>
              </.adj_panel>
            </div>
          </div>

          <div class="border-t border-gray-200 px-5 py-4">
            <div class="flex items-center justify-between text-xs text-gray-600">
              <span>Demo drawer: scrollable, padded, and audit-ready structure.</span>
              <button
                type="button"
                phx-click="close_drawer"
                class="rounded-lg px-2 py-1 text-sm font-semibold text-gray-600 hover:bg-gray-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ----------------------------
  # TopBar events
  # ----------------------------

  @impl true
  def handle_event("topbar_search", %{"query" => q}, socket) do
    {:noreply, assign(socket, :q, q)}
  end

  # ----------------------------
  # Tabs
  # ----------------------------

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    tab =
      if Enum.any?(socket.assigns.tabs, fn t -> t["id"] == tab end) do
        tab
      else
        "pending"
      end

    socket =
      socket
      |> assign(:active_tab, tab)
      |> put_flash(:info, nil)

    {:noreply, socket}
  end

  # ----------------------------
  # Drawer
  # ----------------------------

  @impl true
  def handle_event("close_drawer", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/finished-goods/adjustments")}
  end

  @impl true
  def handle_event("noop_view_attachment", _params, socket) do
    {:noreply, put_flash(socket, :info, "Attachment viewer is a no-op in this demo.")}
  end

  @impl true
  def handle_event("supervisor_notes_change", %{"supervisor_notes" => notes}, socket) do
    {:noreply, assign(socket, :supervisor_notes, notes)}
  end

  # ----------------------------
  # Pending Approvals (Approve / Deny)
  # ----------------------------

  @impl true
  def handle_event("approve_pending", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.pending_approvals, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Pending adjustment not found: #{id}")}

      adj ->
        approved = %{
          id: id,
          timestamp: adj.timestamp,
          requested_by: adj.requested_by,
          sku: adj.sku,
          lot: adj.lot,
          qty: adj.qty,
          reason: adj.reason,
          notes: adj.notes,
          status: "approved",
          approved_by: "S.Kim",
          approved_at: now_stamp(),
          risk_level: adj.risk_level
        }

        socket =
          socket
          |> assign(
            :pending_approvals,
            Enum.reject(socket.assigns.pending_approvals, &(&1.id == id))
          )
          |> assign(:history, [approved | socket.assigns.history])
          |> update_my_requests_status(id, "approved", approved)
          |> log_audit(
            id,
            "approved",
            supervisor_suffix("Approved and recorded.", socket.assigns.supervisor_notes)
          )
          |> compute_stats()
          |> apply_history_filters()
          |> put_flash(:info, "Approved and recorded (demo).")
          |> maybe_close_drawer_if_selected(id)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deny_pending", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.pending_approvals, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Pending adjustment not found: #{id}")}

      adj ->
        denied = %{
          id: id,
          timestamp: adj.timestamp,
          requested_by: adj.requested_by,
          sku: adj.sku,
          lot: adj.lot,
          qty: adj.qty,
          reason: adj.reason,
          notes: adj.notes,
          status: "denied",
          denied_by: "S.Kim",
          denied_at: now_stamp(),
          denial_reason:
            supervisor_suffix("Denied and recorded.", socket.assigns.supervisor_notes),
          risk_level: adj.risk_level,
          approved_by: "—",
          approved_at: "—"
        }

        socket =
          socket
          |> assign(
            :pending_approvals,
            Enum.reject(socket.assigns.pending_approvals, &(&1.id == id))
          )
          |> assign(:history, [denied | socket.assigns.history])
          |> update_my_requests_status(id, "denied", denied)
          |> log_audit(
            id,
            "denied",
            supervisor_suffix("Denied and recorded.", socket.assigns.supervisor_notes)
          )
          |> compute_stats()
          |> apply_history_filters()
          |> put_flash(:info, "Denied and recorded (demo).")
          |> maybe_close_drawer_if_selected(id)

        {:noreply, socket}
    end
  end

  # ----------------------------
  # History filters & pagination
  # ----------------------------

  @impl true
  def handle_event("history_filter", params, socket) do
    search = Map.get(params, "search", socket.assigns.history_search)
    status = Map.get(params, "status", socket.assigns.history_status)
    days = Map.get(params, "days", socket.assigns.history_days)

    socket =
      socket
      |> assign(:history_search, search)
      |> assign(:history_status, status)
      |> assign(:history_days, days)
      |> assign(:history_page, 1)
      |> apply_history_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("history_prev", _params, socket) do
    page = max(socket.assigns.history_page - 1, 1)

    socket =
      socket
      |> assign(:history_page, page)
      |> apply_history_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("history_next", _params, socket) do
    page = socket.assigns.history_page + 1

    socket =
      socket
      |> assign(:history_page, page)
      |> apply_history_filters()

    {:noreply, socket}
  end

  # ----------------------------
  # New Adjustment (form + uploads)
  # ----------------------------

  @impl true
  def handle_event("new_change", params, socket) do
    new_adjustment = Map.merge(socket.assigns.new_adjustment, params)
    errors = validate_new(new_adjustment)

    {:noreply,
     socket
     |> assign(:new_adjustment, new_adjustment)
     |> assign(:new_errors, errors)}
  end

  @impl true
  def handle_event("remove_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :new_attachments, ref)}
  end

  @impl true
  def handle_event("new_reset", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.new_attachments.entries, socket, fn entry, acc ->
        cancel_upload(acc, :new_attachments, entry.ref)
      end)
      |> assign(:new_adjustment, %{
        "sku" => "",
        "lot" => "",
        "location" => "",
        "bin" => "",
        "quantity" => "",
        "reason" => "",
        "notes" => ""
      })
      |> assign(:new_errors, %{})
      |> put_flash(:info, "Form cleared (demo).")

    {:noreply, socket}
  end

  @impl true
  def handle_event("new_submit", _params, socket) do
    errors = validate_new(socket.assigns.new_adjustment)

    if errors != %{} do
      {:noreply,
       socket
       |> assign(:new_errors, errors)
       |> put_flash(:error, "Please fix the highlighted fields.")}
    else
      qty = safe_int(socket.assigns.new_adjustment["quantity"], 0)
      id = next_adj_id(socket.assigns.adj_seq)

      uploaded_names =
        consume_uploaded_entries(socket, :new_attachments, fn %{client_name: name}, _entry ->
          {:ok, name}
        end)

      adj = %{
        id: id,
        timestamp: now_stamp(),
        requested_by: "J.Doe (You)",
        sku: socket.assigns.new_adjustment["sku"],
        lot: socket.assigns.new_adjustment["lot"],
        qty: qty,
        reason: socket.assigns.new_adjustment["reason"],
        notes: socket.assigns.new_adjustment["notes"],
        attachments: uploaded_names,
        risk_level: risk_for_qty(qty),
        status: "pending"
      }

      # Demo routing: new requests are visible under "My Requests" and also queued to "Pending Approvals"
      socket =
        socket
        |> assign(:my_requests, [adj | socket.assigns.my_requests])
        |> assign(:pending_approvals, [
          adj |> Map.put(:requested_by, "J.Doe (You)") | socket.assigns.pending_approvals
        ])
        |> log_audit(id, "submitted", "Submitted for approval.")
        |> assign(:adj_seq, socket.assigns.adj_seq + 1)
        |> compute_stats()
        |> apply_history_filters()
        |> assign(:new_adjustment, %{
          "sku" => "",
          "lot" => "",
          "location" => "",
          "bin" => "",
          "quantity" => "",
          "reason" => "",
          "notes" => ""
        })
        |> assign(:new_errors, %{})
        |> assign(:active_tab, "my-requests")
        |> put_flash(:info, "Submitted for approval (demo).")

      {:noreply, socket}
    end
  end

  # ----------------------------
  # Minimal components (prefixed)
  # ----------------------------

  attr :title, :string, required: true
  slot :inner_block, required: true

  def adj_section(assigns) do
    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white p-5 sm:p-6">
      <div class="mb-4 flex items-center justify-between gap-3">
        <h2 class="text-base font-bold text-gray-900">{@title}</h2>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true

  def adj_stat_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white p-4">
      <div class="flex items-center justify-between gap-3">
        <div>
          <p class="text-xs font-semibold text-gray-500">{@label}</p>
          <p class="mt-1 text-2xl font-bold text-gray-900">{@value}</p>
        </div>
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-gray-50">
          <.adj_icon name={@icon} class="h-5 w-5 text-gray-600" />
        </div>
      </div>
    </div>
    """
  end

  attr :variant, :string, default: "neutral"
  slot :inner_block, required: true

  def adj_badge(assigns) do
    class =
      case assigns.variant do
        "danger" -> "border-red-200 bg-red-50 text-red-800"
        "success" -> "border-green-200 bg-green-50 text-green-800"
        "warning" -> "border-amber-200 bg-amber-50 text-amber-800"
        _ -> "border-gray-200 bg-gray-50 text-gray-800"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-semibold",
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :level, :string, required: true

  def adj_risk_badge(assigns) do
    {label, variant} =
      case assigns.level do
        "medium" -> {"Medium risk", "warning"}
        _ -> {"Low risk", "success"}
      end

    assigns = assign(assigns, :label, label) |> assign(:variant, variant)

    ~H"""
    <.adj_badge variant={@variant}>{@label}</.adj_badge>
    """
  end

  attr :status, :string, required: true

  def adj_status_badge(assigns) do
    {label, variant} =
      case assigns.status do
        "approved" -> {"approved", "success"}
        "denied" -> {"denied", "danger"}
        _ -> {"pending", "warning"}
      end

    assigns = assign(assigns, :label, label) |> assign(:variant, variant)

    ~H"""
    <.adj_badge variant={@variant}>{@label}</.adj_badge>
    """
  end

  attr :variant, :string, default: "primary"
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def adj_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap font-semibold transition " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
        "disabled:opacity-50 disabled:pointer-events-none"

    {variant, size} =
      case assigns.variant do
        "secondary" ->
          {"bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm hover:bg-gray-200", ""}

        "danger" ->
          {"bg-red-600 text-white rounded-full h-9 px-4 text-sm hover:bg-red-700", ""}

        "ghost" ->
          {"text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm", ""}

        _ ->
          {"bg-[#2E7D32] text-white rounded-full h-9 px-4 text-sm hover:brightness-95", ""}
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

  attr :variant, :string, default: "secondary"
  attr :navigate, :string, required: true
  slot :inner_block, required: true

  def adj_link_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap font-semibold transition " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"

    variant =
      case assigns.variant do
        "primary" -> "bg-[#2E7D32] text-white rounded-full h-9 px-4 text-sm hover:brightness-95"
        _ -> "bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm hover:bg-gray-200"
      end

    assigns = assign(assigns, :class, Enum.join([base, variant], " "))

    ~H"""
    <.link navigate={@navigate} class={@class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :type, :string, default: "text"
  attr :value, :string, default: ""
  attr :placeholder, :string, default: nil
  attr :helper, :string, default: nil
  attr :error, :string, default: nil

  def adj_input(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-semibold text-gray-900">{@label}</label>
      <input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class={[
          "mt-1 w-full rounded-xl border bg-white px-3 py-2 text-sm text-gray-900",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
          if(@error, do: "border-red-300", else: "border-gray-300")
        ]}
      />
      <%= if @helper do %>
        <p class="mt-1 text-xs text-gray-500">{@helper}</p>
      <% end %>
      <%= if @error do %>
        <p class="mt-1 text-xs font-semibold text-red-700">{@error}</p>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :options, :list, required: true
  attr :error, :string, default: nil

  def adj_select(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-semibold text-gray-900">{@label}</label>
      <select
        name={@name}
        class={[
          "mt-1 w-full rounded-xl border bg-white px-3 py-2 text-sm text-gray-900",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
          if(@error, do: "border-red-300", else: "border-gray-300")
        ]}
      >
        <%= for {value, label} <- @options do %>
          <option value={value} selected={@value == value}>{label}</option>
        <% end %>
      </select>
      <%= if @error do %>
        <p class="mt-1 text-xs font-semibold text-red-700">{@error}</p>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: nil
  attr :rows, :string, default: "4"
  attr :error, :string, default: nil

  def adj_textarea(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-semibold text-gray-900">{@label}</label>
      <textarea
        name={@name}
        rows={@rows}
        placeholder={@placeholder}
        class={[
          "mt-1 w-full rounded-xl border bg-white px-3 py-2 text-sm text-gray-900",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
          if(@error, do: "border-red-300", else: "border-gray-300")
        ]}
      ><%= @value %></textarea>
      <%= if @error do %>
        <p class="mt-1 text-xs font-semibold text-red-700">{@error}</p>
      <% end %>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  def adj_panel(assigns) do
    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white p-4">
      <h3 class="text-sm font-bold text-gray-900">{@title}</h3>
      <div class="mt-3">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false

  def adj_kv(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3">
      <span class="text-gray-500">{@label}</span>
      <span class={[
        "text-gray-900 font-semibold",
        if(@mono, do: "font-mono text-xs", else: "text-sm")
      ]}>
        {@value}
      </span>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "h-5 w-5 text-gray-600"

  def adj_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "file_edit" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 20h9" />
          <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4 11.5-11.5Z" />
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
      <% "trending_down" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M23 18l-7-7-4 4-7-7" />
          <path d="M17 18h6v-6" />
        </svg>
      <% "image" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2Z" />
          <path d="M8.5 10.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z" />
          <path d="M21 15l-5-5L5 21" />
        </svg>
      <% "upload" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
          <path d="M7 10l5-5 5 5" />
          <path d="M12 5v14" />
        </svg>
      <% "alert_circle" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 22a10 10 0 1 0-10-10 10 10 0 0 0 10 10Z" />
          <path d="M12 8v4" />
          <path d="M12 16h.01" />
        </svg>
      <% _ -> %>
        <span class={@class} />
    <% end %>
    """
  end

  # ----------------------------
  # Helpers
  # ----------------------------

  defp compute_stats(socket) do
    pending = length(socket.assigns.pending_approvals)
    my_pending = Enum.count(socket.assigns.my_requests, &(&1.status == "pending"))

    stats = %{
      pending: pending,
      my_pending: my_pending,
      approved_7d: 12,
      net_change_7d: "-18u",
      avg_approval_time: "8m"
    }

    assign(socket, :stats, stats)
  end

  # ----------------------------
  # History filters & pagination (no Integer.ceil_div/2)
  # ----------------------------

  defp apply_history_filters(socket) do
    search = String.downcase(String.trim(socket.assigns.history_search || ""))
    status = socket.assigns.history_status || "all"

    filtered =
      socket.assigns.history
      |> Enum.filter(fn adj ->
        matches_search? =
          search == "" or
            String.contains?(String.downcase(adj.id), search) or
            String.contains?(String.downcase(adj.sku), search) or
            String.contains?(String.downcase(adj.requested_by), search)

        matches_status? = status == "all" or adj.status == status

        matches_search? and matches_status?
      end)

    total = length(filtered)
    size = max(socket.assigns.history_page_size || 8, 1)

    # ceil(total / size) without Integer.ceil_div/2
    max_page =
      cond do
        total <= 0 -> 1
        true -> div(total + size - 1, size)
      end

    page =
      socket.assigns.history_page
      |> (fn p -> if is_integer(p), do: p, else: 1 end).()
      |> max(1)
      |> min(max_page)

    start_idx = (page - 1) * size

    page_slice =
      filtered
      |> Enum.drop(start_idx)
      |> Enum.take(size)

    socket
    |> assign(:history_total, total)
    |> assign(:history_page, page)
    |> assign(:history_filtered, page_slice)
  end

  defp history_showing_label(page, size, total) do
    if total == 0 do
      "0 of 0"
    else
      start_n = (page - 1) * size + 1
      end_n = min(page * size, total)
      "#{start_n}-#{end_n} of #{total}"
    end
  end

  defp qty_label(qty) when is_integer(qty) do
    sign = if qty > 0, do: "+", else: ""
    "#{sign}#{qty} units"
  end

  defp qty_compact(qty) when is_integer(qty) do
    sign = if qty > 0, do: "+", else: ""
    "#{sign}#{qty}u"
  end

  defp now_stamp do
    # demo-friendly; keeps format similar to provided mock data
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
    |> String.replace("T", " ")
    |> String.slice(0, 16)
  end

  defp safe_int(str, default) do
    case Integer.parse(to_string(str)) do
      {i, _} -> i
      :error -> default
    end
  end

  defp risk_for_qty(qty) do
    if abs(qty) > 5, do: "medium", else: "low"
  end

  defp validate_new(form) do
    required = ["sku", "lot", "quantity", "reason", "notes"]

    base =
      Enum.reduce(required, %{}, fn key, acc ->
        if String.trim(to_string(Map.get(form, key, ""))) == "" do
          Map.put(acc, key, "Required")
        else
          acc
        end
      end)

    qty = safe_int(Map.get(form, "quantity", ""), 0)

    base =
      if Map.get(form, "quantity", "") != "" and qty == 0 do
        Map.put(base, "quantity", "Enter a non-zero quantity")
      else
        base
      end

    base
  end

  defp next_adj_id(seq) do
    "ADJ-" <> String.pad_leading(to_string(seq), 3, "0")
  end

  defp stock_label(stock_by_sku_lot, sku, lot) do
    case get_in(stock_by_sku_lot, [sku, lot]) do
      nil -> "—"
      %{units: u, grams: g} -> "#{u} units (#{g}g)"
    end
  end

  defp supervisor_suffix(base, notes) do
    notes = String.trim(to_string(notes || ""))

    if notes == "" do
      base
    else
      base <> " Supervisor notes: " <> notes
    end
  end

  defp find_in_pending(pending, id), do: Enum.find(pending, &(&1.id == id))

  defp maybe_close_drawer_if_selected(socket, id) do
    if socket.assigns.selected_adjustment && socket.assigns.selected_adjustment.id == id do
      socket
      |> assign(:selected_adjustment, nil)
      |> assign(:supervisor_notes, "")
      |> push_navigate(to: ~p"/finished-goods/adjustments")
    else
      socket
    end
  end

  defp log_audit(socket, id, action, message) do
    event = %{at: now_stamp(), action: action, message: message}

    updated =
      Map.update(socket.assigns.audit_by_id, id, [event], fn list ->
        [event | list]
      end)

    assign(socket, :audit_by_id, updated)
  end

  defp update_my_requests_status(socket, id, status, history_record) do
    my_requests =
      socket.assigns.my_requests
      |> Enum.map(fn r ->
        if r.id == id do
          r
          |> Map.put(:status, status)
          |> maybe_merge_status_fields(history_record)
        else
          r
        end
      end)

    assign(socket, :my_requests, my_requests)
  end

  defp maybe_merge_status_fields(rec, history_record) do
    case history_record.status do
      "approved" ->
        rec
        |> Map.put(:approved_by, history_record.approved_by)
        |> Map.put(:approved_at, history_record.approved_at)

      "denied" ->
        rec
        |> Map.put(:denied_by, history_record.denied_by)
        |> Map.put(:denied_at, history_record.denied_at)
        |> Map.put(:denial_reason, history_record.denial_reason)

      _ ->
        rec
    end
  end

  # ----------------------------
  # Mock options
  # ----------------------------

  defp mock_sku_options do
    [
      {"", "Select SKU"},
      {"LZ-500", "LZ-500 - Fruit Purée (Chilled)"},
      {"SSB-200", "SSB-200 - Small Sauce Bottle"},
      {"STD-300", "STD-300 - Standard Sauce Bottle"},
      {"GJ-206", "GJ-206 - Glass Jar"}
    ]
  end

  defp mock_lot_options("LZ-500"),
    do: [{"", "Select Lot"}, {"LOT-089", "LOT-089"}, {"LOT-090", "LOT-090"}]

  defp mock_lot_options("SSB-200"),
    do: [{"", "Select Lot"}, {"LOT-087", "LOT-087"}, {"LOT-083", "LOT-083"}]

  defp mock_lot_options("STD-300"),
    do: [{"", "Select Lot"}, {"LOT-088", "LOT-088"}, {"LOT-084", "LOT-084"}]

  defp mock_lot_options("GJ-206"),
    do: [{"", "Select Lot"}, {"LOT-086", "LOT-086"}, {"LOT-082", "LOT-082"}]

  defp mock_lot_options(_), do: [{"", "Select Lot"}]

  defp mock_location_options do
    [
      {"", "Select Location"},
      {"Purée Fridge", "Purée Fridge"},
      {"Purée Freezer", "Purée Freezer"},
      {"Dispatch Chiller", "Dispatch Chiller"},
      {"Ambient Rack", "Ambient Rack"}
    ]
  end

  defp mock_reason_options do
    [
      {"", "Select Reason"},
      {"DAMAGED", "DAMAGED"},
      {"EXPIRED", "EXPIRED"},
      {"FOUND", "FOUND (positive adjustment)"},
      {"CYCLE_COUNT", "CYCLE_COUNT_CORRECTION"},
      {"RETURN", "CUSTOMER_RETURN"},
      {"OTHER", "OTHER (requires detailed notes)"}
    ]
  end

  # ----------------------------
  # Mock data (from provided React objects)
  # ----------------------------

  defp mock_data do
    pending_approvals = [
      %{
        id: "ADJ-001",
        timestamp: "2024-12-15 13:45",
        requested_by: "M.Lee",
        sku: "SSB-200",
        lot: "LOT-089",
        qty: -3,
        reason: "DAMAGED",
        notes: "3 bottles leaked during transport to dispatch. Bottles discarded per SOP.",
        attachments: ["IMG_001.jpg", "IMG_002.jpg"],
        risk_level: "low",
        status: "pending"
      },
      %{
        id: "ADJ-002",
        timestamp: "2024-12-15 10:20",
        requested_by: "K.Ng",
        sku: "LZ-500",
        lot: "LOT-090",
        qty: -5,
        reason: "EXPIRED",
        notes: "Units past hard expiry date. Disposed according to waste management protocol.",
        attachments: ["IMG_003.jpg"],
        risk_level: "low",
        status: "pending"
      },
      %{
        id: "ADJ-003",
        timestamp: "2024-12-14 16:00",
        requested_by: "J.Doe",
        sku: "STD-300",
        lot: "LOT-088",
        qty: 2,
        reason: "FOUND",
        notes: "Found 2 units during cycle count that were not recorded in system.",
        attachments: [],
        risk_level: "medium",
        status: "pending"
      }
    ]

    my_requests = [
      %{
        id: "ADJ-004",
        timestamp: "2024-12-15 09:30",
        requested_by: "J.Doe (You)",
        sku: "LZ-500",
        lot: "LOT-089",
        qty: -2,
        reason: "DAMAGED",
        notes: "Packaging torn during handling",
        attachments: ["IMG_004.jpg"],
        risk_level: "low",
        status: "approved",
        approved_by: "S.Kim",
        approved_at: "2024-12-15 09:45"
      },
      %{
        id: "ADJ-005",
        timestamp: "2024-12-14 14:20",
        requested_by: "J.Doe (You)",
        sku: "SSB-200",
        lot: "LOT-087",
        qty: -1,
        reason: "DAMAGED",
        notes: "Bottle cracked",
        attachments: [],
        risk_level: "low",
        status: "pending"
      },
      %{
        id: "ADJ-006",
        timestamp: "2024-12-13 11:00",
        requested_by: "J.Doe (You)",
        sku: "GJ-206",
        lot: "LOT-086",
        qty: 3,
        reason: "FOUND",
        notes: "Found during bin reorganization",
        attachments: [],
        risk_level: "medium",
        status: "denied",
        denied_by: "S.Kim",
        denied_at: "2024-12-13 11:30",
        denial_reason: "Units already recorded in system. Please verify bin location."
      }
    ]

    history = [
      %{
        id: "ADJ-007",
        timestamp: "2024-12-12 15:30",
        requested_by: "M.Lee",
        sku: "LZ-500",
        lot: "LOT-085",
        qty: -8,
        reason: "EXPIRED",
        notes: "Batch past hard expiry",
        status: "approved",
        approved_by: "S.Kim",
        approved_at: "2024-12-12 15:45",
        risk_level: "low"
      },
      %{
        id: "ADJ-008",
        timestamp: "2024-12-11 10:15",
        requested_by: "K.Ng",
        sku: "STD-300",
        lot: "LOT-084",
        qty: -4,
        reason: "DAMAGED",
        notes: "Transport damage",
        status: "approved",
        approved_by: "S.Kim",
        approved_at: "2024-12-11 10:30",
        risk_level: "low"
      },
      %{
        id: "ADJ-009",
        timestamp: "2024-12-10 13:45",
        requested_by: "J.Doe",
        sku: "SSB-200",
        lot: "LOT-083",
        qty: 5,
        reason: "CYCLE_COUNT",
        notes: "Cycle count correction",
        status: "approved",
        approved_by: "S.Kim",
        approved_at: "2024-12-10 14:00",
        risk_level: "medium"
      },
      %{
        id: "ADJ-010",
        timestamp: "2024-12-09 16:20",
        requested_by: "M.Lee",
        sku: "GJ-206",
        lot: "LOT-082",
        qty: -2,
        reason: "RETURN",
        notes: "Customer return - quality issue",
        status: "approved",
        approved_by: "S.Kim",
        approved_at: "2024-12-09 16:35",
        risk_level: "low"
      }
    ]

    {pending_approvals, my_requests, history}
  end

  defp mock_stock do
    %{
      "LZ-500" => %{
        "LOT-089" => %{units: 45, grams: 8100},
        "LOT-090" => %{units: 32, grams: 5760}
      },
      "SSB-200" => %{
        "LOT-089" => %{units: 120, grams: 0},
        "LOT-087" => %{units: 75, grams: 0},
        "LOT-083" => %{units: 90, grams: 0}
      },
      "STD-300" => %{
        "LOT-088" => %{units: 60, grams: 0},
        "LOT-084" => %{units: 48, grams: 0}
      },
      "GJ-206" => %{
        "LOT-086" => %{units: 33, grams: 0},
        "LOT-082" => %{units: 18, grams: 0}
      }
    }
  end
end
