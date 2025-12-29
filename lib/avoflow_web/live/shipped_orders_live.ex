defmodule AvoflowWeb.ShippedOrdersLive do
  use AvoflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    shipped_orders = mock_shipped_orders()

    socket =
      socket
      |> allow_upload(:pod_file,
        accept: ~w(.pdf .png .jpg .jpeg),
        max_entries: 1,
        max_file_size: 8_000_000
      )
      |> assign(:q, "")
      |> assign(:unread_count, 3)
      |> assign(:user_label, "Warehouse Ops")
      # all | awaiting_pod | delivered | exceptions
      |> assign(:filter, "all")
      |> assign(:shipped_orders, shipped_orders)
      |> assign(:selected_order, nil)
      |> assign(:delivery_note_open, false)
      |> assign(:pod_form, %{
        "delivered_at" => "",
        "received_by" => "",
        "receiver_id" => "",
        "notes" => ""
      })
      |> assign(:audit_by_order_id, mock_audit_trails(shipped_orders))
      |> apply_filters()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply,
         socket
         |> assign(:selected_order, nil)
         |> assign(:delivery_note_open, false)
         |> apply_filters()}

      :show ->
        order_id = params["order_id"]

        case find_order(socket.assigns.shipped_orders, order_id) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Shipped order not found: #{order_id}")
             |> push_navigate(to: ~p"/finished-goods/shipped")}

          order ->
            {:noreply,
             socket
             |> assign(:selected_order, order)
             |> assign(:delivery_note_open, false)
             |> hydrate_pod_form(order)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <main class="">
        <div class="">
          <%= if info = Phoenix.Flash.get(@flash, :info) do %>
            <div class="mb-5 rounded-2xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-900">
              {info}
            </div>
          <% end %>

          <%= if error = Phoenix.Flash.get(@flash, :error) do %>
            <div class="mb-5 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900">
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

            <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
              <div class="flex items-start gap-3">
                <div class="w-10 h-10 rounded-xl bg-gray-900 flex items-center justify-center">
                  <.sos_icon name="truck" class="w-6 h-6 text-white" />
                </div>
                <div class="min-w-0">
                  <h1 class="text-2xl font-bold text-gray-900">Shipped Orders</h1>
                  <p class="mt-1 text-sm text-gray-600">
                    Summary, shipment details, and proof-of-receipt capture designed for audit readiness.
                  </p>
                </div>
              </div>

              <%= if @live_action == :index do %>
                <div class="flex flex-wrap items-center gap-2">
                  <div class="rounded-full bg-white border border-gray-200 px-3 py-1.5 text-xs text-gray-600">
                    Visible:
                    <span class="font-semibold text-gray-900">{length(@filtered_orders)}</span>
                  </div>
                  <div class="rounded-full bg-white border border-gray-200 px-3 py-1.5 text-xs text-gray-600">
                    Awaiting POD:
                    <span class="font-semibold text-gray-900">{@counts.awaiting_pod}</span>
                  </div>
                  <div class="rounded-full bg-white border border-gray-200 px-3 py-1.5 text-xs text-gray-600">
                    Exceptions: <span class="font-semibold text-gray-900">{@counts.exceptions}</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%= if @live_action == :index do %>
            <div class="space-y-6">
              <!-- Summary -->
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <.sos_stat_card
                  label="Shipped"
                  value={@summary.shipped_count}
                  hint="Total in mock list"
                  icon="box"
                />
                <.sos_stat_card
                  label="Delivered"
                  value={@summary.delivered_count}
                  hint="POD recorded"
                  icon="check"
                />
                <.sos_stat_card
                  label="Awaiting POD"
                  value={@summary.awaiting_pod_count}
                  hint="Needs confirmation"
                  icon="file"
                />
                <.sos_stat_card
                  label="Exceptions"
                  value={@summary.exception_count}
                  hint="Missing required fields"
                  icon="alert"
                />
              </div>
              
    <!-- Filters -->
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div class="inline-flex flex-wrap gap-2 rounded-2xl border border-gray-200 bg-white p-2">
                  <.sos_filter_button
                    active={@filter == "all"}
                    phx-click="set_filter"
                    phx-value-filter="all"
                  >
                    All
                    <span class="ml-2 rounded-full bg-gray-100 px-2 py-0.5 text-[11px] font-semibold text-gray-700 border border-gray-200">
                      {@counts.all}
                    </span>
                  </.sos_filter_button>

                  <.sos_filter_button
                    active={@filter == "awaiting_pod"}
                    phx-click="set_filter"
                    phx-value-filter="awaiting_pod"
                  >
                    Awaiting POD
                    <span class="ml-2 rounded-full bg-gray-100 px-2 py-0.5 text-[11px] font-semibold text-gray-700 border border-gray-200">
                      {@counts.awaiting_pod}
                    </span>
                  </.sos_filter_button>

                  <.sos_filter_button
                    active={@filter == "delivered"}
                    phx-click="set_filter"
                    phx-value-filter="delivered"
                  >
                    Delivered
                    <span class="ml-2 rounded-full bg-gray-100 px-2 py-0.5 text-[11px] font-semibold text-gray-700 border border-gray-200">
                      {@counts.delivered}
                    </span>
                  </.sos_filter_button>

                  <.sos_filter_button
                    active={@filter == "exceptions"}
                    phx-click="set_filter"
                    phx-value-filter="exceptions"
                  >
                    Exceptions
                    <span class="ml-2 rounded-full bg-gray-100 px-2 py-0.5 text-[11px] font-semibold text-gray-700 border border-gray-200">
                      {@counts.exceptions}
                    </span>
                  </.sos_filter_button>
                </div>

                <div class="text-xs text-gray-500">
                  Tip: Use TopBar search to filter by order id, customer, carrier, tracking, or delivery note.
                </div>
              </div>
              
    <!-- List -->
              <.sos_card title="Shipped Orders (click a row for details)" compact>
                <div class="rounded-xl border border-gray-200 bg-white">
                  <div class="overflow-x-auto">
                    <table class="min-w-[980px] w-full text-sm">
                      <thead class="text-xs text-gray-600 bg-gray-50">
                        <tr class="border-b border-gray-200">
                          <th class="py-3 px-4 text-left font-semibold">Order</th>
                          <th class="py-3 px-4 text-left font-semibold">Customer</th>
                          <th class="py-3 px-4 text-left font-semibold">Ship Date</th>
                          <th class="py-3 px-4 text-left font-semibold">Carrier</th>
                          <th class="py-3 px-4 text-left font-semibold">Tracking</th>
                          <th class="py-3 px-4 text-left font-semibold">Status</th>
                          <th class="py-3 px-4 text-left font-semibold">Proof</th>
                        </tr>
                      </thead>

                      <tbody class="divide-y divide-gray-200">
                        <%= for order <- @filtered_orders do %>
                          <tr
                            class={[
                              "group cursor-pointer transition",
                              "hover:bg-gray-50",
                              if(exception?(order), do: "bg-red-50/40", else: "")
                            ]}
                            phx-click="open_order"
                            phx-value-id={order.id}
                            role="button"
                            tabindex="0"
                          >
                            <td class="py-4 px-4 align-top">
                              <div class="flex items-start gap-3">
                                <div class={[
                                  "mt-1 h-2.5 w-2.5 rounded-full shrink-0",
                                  if(exception?(order),
                                    do: "bg-red-600",
                                    else:
                                      if(pod_present?(order.pod),
                                        do: "bg-green-700",
                                        else: "bg-amber-600"
                                      )
                                  )
                                ]} />
                                <div class="min-w-0">
                                  <div class="font-semibold text-gray-900">{order.id}</div>
                                  <div class="mt-1 text-xs text-gray-600 break-words">
                                    {length(order.lines)} SKUs • {order.shipment.delivery_note_no}
                                  </div>
                                </div>
                              </div>
                            </td>

                            <td class="py-4 px-4 align-top min-w-[240px]">
                              <div class="text-gray-900 font-medium break-words">
                                {order.customer}
                              </div>
                              <div class="mt-1 text-xs text-gray-600 break-words">
                                Consignee: {order.shipment.consignee}
                              </div>
                            </td>

                            <td class="py-4 px-4 align-top whitespace-nowrap text-gray-700">
                              {order.shipment.shipped_date}
                            </td>

                            <td class="py-4 px-4 align-top min-w-[180px]">
                              <div class="text-gray-900 font-medium break-words">
                                {order.shipment.carrier}
                              </div>
                              <div class="mt-1 text-xs text-gray-600 break-words">
                                {order.shipment.service_level}
                              </div>
                            </td>

                            <td class="py-4 px-4 align-top min-w-[220px]">
                              <div class="text-gray-900 font-semibold break-all font-mono">
                                <%= if present?(order.shipment.tracking_number) do %>
                                  {order.shipment.tracking_number}
                                <% else %>
                                  <span class="text-red-700">Missing</span>
                                <% end %>
                              </div>
                              <div class="mt-1 text-xs text-gray-600 break-all">
                                Move: {order.shipment.movement_ref}
                              </div>
                            </td>

                            <td class="py-4 px-4 align-top whitespace-nowrap">
                              <.sos_badge variant={status_badge(order.status)}>
                                {order.status}
                              </.sos_badge>
                            </td>

                            <td class="py-4 px-4 align-top">
                              <div class="flex flex-wrap items-center gap-2">
                                <.sos_badge variant={pod_badge(order.pod)}>
                                  {if pod_present?(order.pod), do: "POD attached", else: "Missing POD"}
                                </.sos_badge>

                                <%= if exception?(order) do %>
                                  <span class="text-xs font-semibold text-red-700">
                                    Needs attention
                                  </span>
                                <% end %>
                              </div>
                            </td>
                          </tr>
                        <% end %>

                        <%= if @filtered_orders == [] do %>
                          <tr>
                            <td colspan="7" class="py-10 px-4 text-center">
                              <div class="mx-auto max-w-md">
                                <div class="mx-auto mb-3 h-10 w-10 rounded-2xl bg-gray-100 border border-gray-200 flex items-center justify-center">
                                  <.sos_icon name="search" class="w-5 h-5 text-gray-600" />
                                </div>
                                <p class="text-sm font-semibold text-gray-900">
                                  No matching shipped orders
                                </p>
                                <p class="mt-1 text-sm text-gray-600">
                                  Adjust filters or refine your search (order id, customer, carrier, tracking, delivery note).
                                </p>
                              </div>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </.sos_card>
            </div>
          <% else %>
            <!-- DETAILS -->
            <div class="space-y-6">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <.sos_link_button navigate={~p"/finished-goods/shipped"} variant="ghost">
                      ← Back
                    </.sos_link_button>

                    <h2 class="text-lg font-bold text-gray-900">{@selected_order.id}</h2>

                    <.sos_badge variant={status_badge(@selected_order.status)}>
                      {@selected_order.status}
                    </.sos_badge>
                    <.sos_badge variant={pod_badge(@selected_order.pod)}>
                      {if pod_present?(@selected_order.pod), do: "POD ready", else: "POD missing"}
                    </.sos_badge>

                    <%= if exception?(@selected_order) do %>
                      <.sos_badge variant="danger">Exception</.sos_badge>
                    <% end %>
                  </div>

                  <p class="text-sm text-gray-600 mt-2 break-words">
                    Customer:
                    <span class="font-semibold text-gray-900">{@selected_order.customer}</span>
                    • Ship Date:
                    <span class="font-semibold text-gray-900">
                      {@selected_order.shipment.shipped_date}
                    </span>
                    • Carrier:
                    <span class="font-semibold text-gray-900 break-words">
                      {@selected_order.shipment.carrier}
                    </span>
                  </p>
                </div>

                <div class="flex flex-wrap items-center gap-2">
                  <.sos_button variant="secondary" phx-click="open_delivery_note">
                    View Delivery Note
                  </.sos_button>

                  <.sos_button variant="secondary" phx-click="export_audit_stub">
                    Export Audit Summary (Demo)
                  </.sos_button>
                </div>
              </div>

              <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <!-- Shipment + Line details -->
                <div class="lg:col-span-2 space-y-6">
                  <.sos_card title="Shipment Summary">
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                        <p class="text-xs text-gray-600">Delivery Note</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-words">
                          {@selected_order.shipment.delivery_note_no}
                        </p>
                        <p class="text-xs text-gray-600 mt-3">Stock Movement Ref</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-all font-mono">
                          {@selected_order.shipment.movement_ref}
                        </p>
                      </div>

                      <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                        <p class="text-xs text-gray-600">Tracking</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-all font-mono">
                          <%= if present?(@selected_order.shipment.tracking_number) do %>
                            {@selected_order.shipment.tracking_number}
                          <% else %>
                            <span class="text-red-700">Missing</span>
                          <% end %>
                        </p>
                        <p class="text-xs text-gray-600 mt-3">Service</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-words">
                          {@selected_order.shipment.service_level}
                        </p>
                      </div>

                      <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                        <p class="text-xs text-gray-600">Packed By</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-words">
                          {@selected_order.shipment.packed_by}
                        </p>
                        <p class="text-xs text-gray-600 mt-3">Verified By</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-words">
                          <%= if present?(@selected_order.shipment.verified_by) do %>
                            {@selected_order.shipment.verified_by}
                          <% else %>
                            <span class="text-red-700">Missing</span>
                          <% end %>
                        </p>
                      </div>

                      <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                        <p class="text-xs text-gray-600">Consignee</p>
                        <p class="text-sm font-semibold text-gray-900 mt-1 break-words">
                          {@selected_order.shipment.consignee}
                        </p>
                        <p class="text-xs text-gray-600 mt-3">Delivery Address</p>
                        <p class="text-xs text-gray-700 mt-1 break-words">
                          {@selected_order.shipment.delivery_address}
                        </p>
                      </div>
                    </div>

                    <div class="mt-5 rounded-xl border border-gray-200 bg-white p-4">
                      <div class="flex items-start gap-2">
                        <.sos_icon name="info" class="w-5 h-5 text-gray-700 mt-0.5" />
                        <div class="text-sm text-gray-800">
                          <p class="font-semibold text-gray-900">Audit readiness</p>
                          <p class="text-xs text-gray-600 mt-1">
                            Keep shipment identifiers, lot/expiry traceability, and POD metadata together with a timestamped audit trail.
                          </p>
                        </div>
                      </div>
                    </div>
                  </.sos_card>

                  <.sos_card title="Line Items (with lot traceability)">
                    <div class="rounded-xl border border-gray-200 bg-white">
                      <div class="overflow-x-auto">
                        <table class="min-w-[900px] w-full text-sm">
                          <thead class="text-xs text-gray-600 bg-gray-50">
                            <tr class="border-b border-gray-200">
                              <th class="py-3 px-4 text-left font-semibold">SKU</th>
                              <th class="py-3 px-4 text-left font-semibold">Description</th>
                              <th class="py-3 px-4 text-left font-semibold">Qty</th>
                              <th class="py-3 px-4 text-left font-semibold">Temp</th>
                              <th class="py-3 px-4 text-left font-semibold">Lots / Expiry / Qty</th>
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-gray-200">
                            <%= for line <- @selected_order.lines do %>
                              <tr class="hover:bg-gray-50">
                                <td class="py-4 px-4 align-top whitespace-nowrap">
                                  <div class="font-semibold text-gray-900">{line.sku_code}</div>
                                  <div class="mt-1 text-xs text-gray-600">UOM: {line.uom}</div>
                                </td>

                                <td class="py-4 px-4 align-top min-w-[260px]">
                                  <div class="text-gray-900 break-words">{line.sku_name}</div>
                                </td>

                                <td class="py-4 px-4 align-top whitespace-nowrap text-gray-700 font-semibold">
                                  {line.qty} {line.uom}
                                </td>

                                <td class="py-4 px-4 align-top whitespace-nowrap">
                                  <.sos_badge variant="neutral">{line.temp_zone}</.sos_badge>
                                </td>

                                <td class="py-4 px-4 align-top">
                                  <div class="space-y-2">
                                    <%= for lot <- line.lots do %>
                                      <div class="flex flex-wrap items-start justify-between gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-xs">
                                        <div class="text-gray-700 break-words">
                                          <span class="font-semibold text-gray-900">
                                            {lot.lot_id}
                                          </span>
                                          <span class="text-gray-600">• Exp {lot.expiry_date}</span>
                                        </div>
                                        <div class="text-gray-700">
                                          <span class="text-gray-600">Qty:</span>
                                          <span class="font-semibold text-gray-900">{lot.qty}</span>
                                        </div>
                                      </div>
                                    <% end %>
                                  </div>
                                </td>
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </.sos_card>

                  <.sos_card title="Audit Trail">
                    <div class="rounded-xl border border-gray-200 bg-white">
                      <div class="overflow-x-auto">
                        <table class="min-w-[860px] w-full text-sm">
                          <thead class="text-xs text-gray-600 bg-gray-50">
                            <tr class="border-b border-gray-200">
                              <th class="py-3 px-4 text-left font-semibold">Timestamp</th>
                              <th class="py-3 px-4 text-left font-semibold">Actor</th>
                              <th class="py-3 px-4 text-left font-semibold">Action</th>
                              <th class="py-3 px-4 text-left font-semibold">Details</th>
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-gray-200">
                            <%= for ev <- audit_for(@audit_by_order_id, @selected_order.id) do %>
                              <tr class="hover:bg-gray-50">
                                <td class="py-3 px-4 whitespace-nowrap text-gray-700">{ev.at}</td>
                                <td class="py-3 px-4 whitespace-nowrap text-gray-900 font-semibold">
                                  {ev.actor}
                                </td>
                                <td class="py-3 px-4 whitespace-nowrap">
                                  <.sos_badge variant="neutral">{ev.action}</.sos_badge>
                                </td>
                                <td class="py-3 px-4 text-gray-700 break-words">{ev.details}</td>
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                    </div>

                    <div class="mt-4 text-xs text-gray-500">
                      Demo note: In production, persist immutably (append-only) and include request IDs / device IDs.
                    </div>
                  </.sos_card>
                </div>
                
    <!-- Proof of Receipt + Checklist -->
                <div class="space-y-6">
                  <.sos_card title="Proof of Delivery (POD)">
                    <%= if pod_present?(@selected_order.pod) do %>
                      <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                        <p class="text-sm font-semibold text-gray-900">POD recorded</p>
                        <p class="text-xs text-gray-700 mt-2 break-words">
                          Delivered at:
                          <span class="font-semibold">{@selected_order.pod.delivered_at}</span>
                          • Received by:
                          <span class="font-semibold">{@selected_order.pod.received_by}</span>
                        </p>

                        <%= if present?(@selected_order.pod.receiver_id) do %>
                          <p class="text-xs text-gray-700 mt-1 break-words">
                            Receiver ref:
                            <span class="font-semibold">{@selected_order.pod.receiver_id}</span>
                          </p>
                        <% end %>

                        <%= if @selected_order.pod.files != [] do %>
                          <div class="mt-3 text-xs text-gray-700">
                            Attachments:
                            <ul class="mt-1 list-disc pl-5 space-y-1">
                              <%= for f <- @selected_order.pod.files do %>
                                <li class="break-all">{f.client_name} ({format_bytes(f.size)})</li>
                              <% end %>
                            </ul>
                          </div>
                        <% end %>

                        <div class="mt-4 flex flex-wrap gap-2">
                          <.sos_button variant="secondary" phx-click="clear_pod">
                            Replace / Update POD
                          </.sos_button>
                        </div>
                      </div>
                    <% else %>
                      <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                        <p class="text-sm font-semibold text-gray-900">POD missing</p>
                        <p class="text-xs text-gray-700 mt-2">
                          Capture delivery confirmation, receiver identity, and attachment if available.
                        </p>
                      </div>
                    <% end %>

                    <%= if not pod_present?(@selected_order.pod) do %>
                      <form phx-submit="save_pod" phx-change="pod_change" class="mt-4 space-y-4">
                        <.sos_input
                          label="Delivered At (ISO Date/Time)"
                          name="delivered_at"
                          value={@pod_form["delivered_at"]}
                          placeholder="e.g., 2025-12-28 14:35"
                        />

                        <.sos_input
                          label="Received By (Name)"
                          name="received_by"
                          value={@pod_form["received_by"]}
                          placeholder="e.g., S. Kimani"
                        />

                        <.sos_input
                          label="Receiver ID / Ref"
                          name="receiver_id"
                          value={@pod_form["receiver_id"]}
                          placeholder="e.g., ID-77821 / Gate Pass"
                        />

                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1.5">
                            Delivery Notes
                          </label>
                          <textarea
                            name="notes"
                            rows="3"
                            class="w-full rounded-xl border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                            placeholder="Any exceptions: temperature, damage, partial delivery, etc."
                          ><%= @pod_form["notes"] %></textarea>
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1.5">
                            Attach POD File (optional)
                          </label>
                          <div class="rounded-xl border border-gray-200 bg-white p-4">
                            <.live_file_input
                              upload={@uploads.pod_file}
                              class="block w-full text-sm text-gray-700 file:mr-3 file:rounded-full file:border-0 file:bg-gray-100 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-gray-900 hover:file:bg-gray-200"
                            />

                            <%= for entry <- @uploads.pod_file.entries do %>
                              <div class="mt-3 flex items-center justify-between gap-2 rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-xs text-gray-700">
                                <div class="min-w-0 break-all">
                                  <span class="font-semibold text-gray-900">{entry.client_name}</span>
                                  <span class="text-gray-600">
                                    ({format_bytes(entry.client_size)})
                                  </span>
                                </div>
                                <button
                                  type="button"
                                  phx-click="cancel_upload"
                                  phx-value-ref={entry.ref}
                                  class="text-gray-700 hover:bg-gray-200/60 rounded-lg px-2 py-1 text-xs focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                                >
                                  Remove
                                </button>
                              </div>
                            <% end %>

                            <%= for err <- upload_errors(@uploads.pod_file) do %>
                              <div class="mt-2 text-xs text-red-600">
                                Upload error: {inspect(err)}
                              </div>
                            <% end %>

                            <p class="mt-3 text-xs text-gray-500">
                              Accepted: PDF/JPG/PNG (max 8MB). Demo stores metadata in memory only.
                            </p>
                          </div>
                        </div>

                        <div class="flex flex-col sm:flex-row gap-2">
                          <.sos_button variant="primary" type="submit">
                            Save POD & Mark Delivered
                          </.sos_button>
                          <.sos_button
                            variant="secondary"
                            type="button"
                            phx-click="open_delivery_note"
                          >
                            Review Delivery Note
                          </.sos_button>
                        </div>
                      </form>
                    <% end %>
                  </.sos_card>

                  <.sos_card title="Audit Checklist (fast)">
                    <div class="space-y-3 text-sm">
                      <.sos_check_item
                        ok={present?(@selected_order.shipment.tracking_number)}
                        label="Tracking number present"
                        hint={
                          if present?(@selected_order.shipment.tracking_number),
                            do: @selected_order.shipment.tracking_number,
                            else: "Missing"
                        }
                      />
                      <.sos_check_item
                        ok={present?(@selected_order.shipment.delivery_note_no)}
                        label="Delivery note reference present"
                        hint={@selected_order.shipment.delivery_note_no}
                      />
                      <.sos_check_item
                        ok={all_lines_have_lots?(@selected_order)}
                        label="Lot/expiry traceability captured"
                        hint="All SKUs list lots & expiries"
                      />
                      <.sos_check_item
                        ok={pod_present?(@selected_order.pod)}
                        label="Proof of delivery recorded"
                        hint={
                          if pod_present?(@selected_order.pod),
                            do: "Delivered to #{@selected_order.pod.received_by}",
                            else: "Missing"
                        }
                      />
                      <.sos_check_item
                        ok={present?(@selected_order.shipment.verified_by)}
                        label="Verification field present"
                        hint={
                          if present?(@selected_order.shipment.verified_by),
                            do: @selected_order.shipment.verified_by,
                            else: "Missing"
                        }
                      />
                    </div>

                    <div class="mt-4 rounded-xl border border-gray-200 bg-gray-50 p-4 text-xs text-gray-700 break-words">
                      Recommended audit practice: store immutable delivery note PDF, POD file, and shipment event IDs; include device/user IDs for each capture.
                    </div>
                  </.sos_card>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>

    <!-- Delivery Note Modal (printable demo) -->
    <%= if @delivery_note_open and @selected_order do %>
      <div
        class="fixed inset-0 z-50"
        phx-window-keydown="close_delivery_note"
        phx-key="escape"
        role="dialog"
        aria-modal="true"
      >
        <div class="absolute inset-0 bg-black/40" phx-click="close_delivery_note"></div>

        <div class="relative mx-auto mt-6 sm:mt-10 w-full max-w-3xl px-4">
          <div class="rounded-2xl bg-white border border-gray-200 overflow-hidden max-h-[calc(100vh-6rem)]">
            <div class="flex items-start justify-between gap-3 px-5 py-4 border-b border-gray-200 bg-gray-50">
              <div class="min-w-0">
                <p class="text-sm font-semibold text-gray-900">Delivery Note (Demo)</p>
                <p class="text-xs text-gray-600 mt-1">
                  Use your browser print function for a physical copy. This is a printable layout stub.
                </p>
              </div>

              <button
                type="button"
                class="rounded-lg p-2 text-gray-700 hover:bg-gray-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                phx-click="close_delivery_note"
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            <div class="px-6 py-6 space-y-6 overflow-y-auto max-h-[calc(100vh-10rem)]">
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                <div class="min-w-0">
                  <p class="text-xs text-gray-500">From</p>
                  <p class="text-sm font-semibold text-gray-900">Avoflow Warehouse</p>
                  <p class="text-xs text-gray-700 mt-1">Industrial Area • Nairobi</p>
                </div>

                <div class="min-w-0">
                  <p class="text-xs text-gray-500">To (Consignee)</p>
                  <p class="text-sm font-semibold text-gray-900 break-words">
                    {@selected_order.shipment.consignee}
                  </p>
                  <p class="text-xs text-gray-700 mt-1 break-words">
                    {@selected_order.shipment.delivery_address}
                  </p>
                </div>

                <div class="min-w-0">
                  <p class="text-xs text-gray-500">References</p>
                  <p class="text-sm font-semibold text-gray-900 break-words">
                    {@selected_order.shipment.delivery_note_no}
                  </p>
                  <p class="text-xs text-gray-700 mt-1">Order: {@selected_order.id}</p>
                  <p class="text-xs text-gray-700">
                    Ship Date: {@selected_order.shipment.shipped_date}
                  </p>
                </div>
              </div>

              <div class="rounded-xl border border-gray-200 bg-white">
                <div class="overflow-x-auto">
                  <table class="min-w-[760px] w-full text-sm">
                    <thead class="text-xs text-gray-600 bg-gray-50">
                      <tr class="border-b border-gray-200">
                        <th class="py-2 px-4 text-left font-semibold">SKU</th>
                        <th class="py-2 px-4 text-left font-semibold">Description</th>
                        <th class="py-2 px-4 text-left font-semibold">Qty</th>
                        <th class="py-2 px-4 text-left font-semibold">Lots</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                      <%= for line <- @selected_order.lines do %>
                        <tr>
                          <td class="py-3 px-4 font-semibold text-gray-900 whitespace-nowrap">
                            {line.sku_code}
                          </td>
                          <td class="py-3 px-4 text-gray-700 break-words">{line.sku_name}</td>
                          <td class="py-3 px-4 text-gray-700 whitespace-nowrap">
                            {line.qty} {line.uom}
                          </td>
                          <td class="py-3 px-4 text-xs text-gray-700">
                            <div class="space-y-1">
                              <%= for lot <- line.lots do %>
                                <div class="break-words">
                                  <span class="font-semibold text-gray-900">{lot.lot_id}</span>
                                  <span class="text-gray-600">
                                    • Exp {lot.expiry_date} • Qty {lot.qty}
                                  </span>
                                </div>
                              <% end %>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                  <p class="text-xs text-gray-600">Carrier</p>
                  <p class="text-sm font-semibold text-gray-900 mt-1 break-words">
                    {@selected_order.shipment.carrier}
                  </p>
                  <p class="text-xs text-gray-600 mt-3">Tracking</p>
                  <p class="text-sm font-semibold text-gray-900 mt-1 break-all font-mono">
                    <%= if present?(@selected_order.shipment.tracking_number) do %>
                      {@selected_order.shipment.tracking_number}
                    <% else %>
                      <span class="text-red-700">Missing</span>
                    <% end %>
                  </p>
                </div>

                <div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
                  <p class="text-xs text-gray-600">Receiver Sign-off</p>
                  <p class="text-xs text-gray-700 mt-3">Name: ________________________________</p>
                  <p class="text-xs text-gray-700 mt-3">Signature: ____________________________</p>
                  <p class="text-xs text-gray-700 mt-3">Date/Time: ____________________________</p>
                </div>
              </div>

              <div class="flex flex-col sm:flex-row gap-2">
                <.sos_button variant="secondary" type="button" phx-click="close_delivery_note">
                  Close
                </.sos_button>
                <div class="text-xs text-gray-500 sm:ml-auto sm:text-right pt-2">
                  Demo: record POD after client signs this delivery note.
                </div>
              </div>
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
  # Events
  # ----------------------------

  @impl true
  def handle_event("topbar_search", %{"query" => q}, socket) do
    {:noreply, socket |> assign(:q, q) |> apply_filters()}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket)
      when filter in ["all", "awaiting_pod", "delivered", "exceptions"] do
    {:noreply, socket |> assign(:filter, filter) |> apply_filters()}
  end

  @impl true
  def handle_event("open_order", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/finished-goods/shipped/#{id}")}
  end

  @impl true
  def handle_event("open_delivery_note", _params, socket) do
    socket =
      socket
      |> assign(:delivery_note_open, true)
      |> log_audit(
        socket.assigns.selected_order && socket.assigns.selected_order.id,
        "delivery_note.viewed",
        "Delivery note preview opened"
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_delivery_note", _params, socket) do
    {:noreply, assign(socket, :delivery_note_open, false)}
  end

  @impl true
  def handle_event("pod_change", params, socket) do
    {:noreply, assign(socket, :pod_form, Map.merge(socket.assigns.pod_form, params))}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pod_file, ref)}
  end

  @impl true
  def handle_event("save_pod", params, socket) do
    order = socket.assigns.selected_order

    if is_nil(order) do
      {:noreply, put_flash(socket, :error, "No order selected.")}
    else
      delivered_at =
        String.trim(to_string(params["delivered_at"] || socket.assigns.pod_form["delivered_at"]))

      received_by =
        String.trim(to_string(params["received_by"] || socket.assigns.pod_form["received_by"]))

      receiver_id =
        String.trim(to_string(params["receiver_id"] || socket.assigns.pod_form["receiver_id"]))

      notes = String.trim(to_string(params["notes"] || socket.assigns.pod_form["notes"]))

      cond do
        delivered_at == "" ->
          {:noreply, put_flash(socket, :error, "Delivered At is required for POD.")}

        received_by == "" ->
          {:noreply, put_flash(socket, :error, "Received By is required for POD.")}

        true ->
          files =
            consume_uploaded_entries(socket, :pod_file, fn %{
                                                             client_name: name,
                                                             client_size: size,
                                                             client_type: type
                                                           },
                                                           _entry ->
              {:ok, %{client_name: name, size: size, type: type}}
            end)

          new_pod = %{
            delivered_at: delivered_at,
            received_by: received_by,
            receiver_id: receiver_id,
            notes: notes,
            files: files
          }

          socket =
            socket
            |> update_order(order.id, fn o ->
              o
              |> Map.put(:pod, new_pod)
              |> Map.put(:status, "delivered")
            end)
            |> assign(:pod_form, %{
              "delivered_at" => delivered_at,
              "received_by" => received_by,
              "receiver_id" => receiver_id,
              "notes" => notes
            })
            |> log_audit(
              order.id,
              "pod.recorded",
              "Delivered at #{delivered_at}; received by #{received_by}" <>
                if(receiver_id != "", do: " (#{receiver_id})", else: "") <>
                if(files != [], do: "; attachment: #{List.first(files).client_name}", else: "")
            )
            |> put_flash(:info, "POD saved and order marked delivered (demo).")
            |> apply_filters()

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("clear_pod", _params, socket) do
    order = socket.assigns.selected_order

    if is_nil(order) do
      {:noreply, socket}
    else
      socket =
        socket
        |> update_order(order.id, fn o ->
          o |> Map.put(:pod, nil) |> Map.put(:status, "shipped")
        end)
        |> assign(:pod_form, %{
          "delivered_at" => "",
          "received_by" => "",
          "receiver_id" => "",
          "notes" => ""
        })
        |> log_audit(order.id, "pod.cleared", "POD cleared for replacement (demo)")
        |> put_flash(:info, "POD cleared. You can record a new one (demo).")
        |> apply_filters()

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("export_audit_stub", _params, socket) do
    order = socket.assigns.selected_order

    if is_nil(order) do
      {:noreply, socket}
    else
      socket =
        socket
        |> log_audit(order.id, "audit.exported", "Audit export requested (demo)")
        |> put_flash(
          :info,
          "Audit export requested (demo). In production, generate a signed PDF/CSV bundle."
        )

      {:noreply, socket}
    end
  end

  # ----------------------------
  # Function components (prefixed)
  # ----------------------------

  attr :title, :string, default: nil
  attr :compact, :boolean, default: false
  slot :inner_block, required: true

  def sos_card(assigns) do
    ~H"""
    <div class="rounded-2xl bg-white border border-gray-200">
      <%= if @title do %>
        <div class="px-6 pt-6">
          <div class="flex items-center justify-between gap-3">
            <h3 class="text-base font-bold text-gray-900">{@title}</h3>
          </div>
        </div>
      <% end %>

      <div class={["px-6", if(@compact, do: "pt-4 pb-6", else: "py-6")]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  attr :icon, :string, default: nil

  def sos_stat_card(assigns) do
    ~H"""
    <div class="rounded-2xl bg-white border border-gray-200 p-5">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="text-xs text-gray-600">{@label}</p>
          <p class="mt-2 text-2xl font-bold text-gray-900">{@value}</p>
        </div>

        <%= if @icon do %>
          <div class="h-10 w-10 rounded-xl bg-gray-50 border border-gray-200 flex items-center justify-center">
            <.sos_icon name={@icon} class="w-5 h-5 text-gray-700" />
          </div>
        <% end %>
      </div>

      <%= if @hint do %>
        <p class="mt-3 text-xs text-gray-500">{@hint}</p>
      <% end %>
    </div>
    """
  end

  attr :active, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def sos_filter_button(assigns) do
    assigns =
      assign(
        assigns,
        :class,
        if(assigns.active,
          do: "bg-gray-900 text-white border-gray-900",
          else: "bg-white text-gray-900 border-gray-200 hover:bg-gray-50"
        )
      )

    ~H"""
    <button
      type="button"
      class={[
        "inline-flex items-center rounded-full h-9 px-4 text-sm font-semibold transition border",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :variant, :string, default: "neutral"
  slot :inner_block, required: true

  def sos_badge(assigns) do
    class =
      case assigns.variant do
        "danger" -> "bg-red-50 text-red-800 border border-red-200"
        "success" -> "bg-green-50 text-green-800 border border-green-200"
        "warning" -> "bg-amber-50 text-amber-800 border border-amber-200"
        _ -> "bg-gray-100 text-gray-800 border border-gray-200"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold",
      @class
    ]}>
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

  def sos_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap font-semibold transition " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
        "disabled:opacity-50 disabled:pointer-events-none"

    variant =
      case assigns.variant do
        "secondary" ->
          "bg-white text-gray-900 border border-gray-200 rounded-full hover:bg-gray-50"

        "ghost" ->
          "text-gray-700 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"

        _ ->
          "bg-[#2E7D32] text-white rounded-full"
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

  def sos_link_button(assigns) do
    base =
      "inline-flex items-center justify-center whitespace-nowrap font-semibold transition " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"

    variant =
      case assigns.variant do
        "secondary" ->
          "bg-white text-gray-900 border border-gray-200 rounded-full hover:bg-gray-50"

        "ghost" ->
          "text-gray-700 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"

        _ ->
          "bg-[#2E7D32] text-white rounded-full"
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

  def sos_input(assigns) do
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
          "w-full rounded-xl border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2",
          if(@readonly, do: "bg-gray-50 text-gray-700", else: "")
        ]}
      />
    </div>
    """
  end

  attr :ok, :boolean, required: true
  attr :label, :string, required: true
  attr :hint, :string, default: nil

  def sos_check_item(assigns) do
    ~H"""
    <div class="flex items-start gap-2">
      <div class={[
        "mt-0.5 h-5 w-5 rounded-full flex items-center justify-center text-xs font-bold",
        if(@ok, do: "bg-green-700 text-white", else: "bg-amber-600 text-white")
      ]}>
        {if @ok, do: "✓", else: "!"}
      </div>
      <div class="min-w-0">
        <p class="font-semibold text-gray-900 text-sm">{@label}</p>
        <%= if @hint do %>
          <p class="text-xs text-gray-600 mt-1 break-words">{@hint}</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "w-5 h-5 text-gray-600"

  def sos_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "truck" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 16V6a2 2 0 0 1 2-2h10v12H3Z" />
          <path d="M15 8h4l2 3v5h-6V8Z" />
          <path d="M7 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
          <path d="M17 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
        </svg>
      <% "info" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 22a10 10 0 1 0-10-10 10 10 0 0 0 10 10Z" />
          <path d="M12 16v-4" />
          <path d="M12 8h.01" />
        </svg>
      <% "search" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16Z" />
          <path d="M21 21l-4.3-4.3" />
        </svg>
      <% "box" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 16V8a2 2 0 0 0-1-1.73L13 2.27a2 2 0 0 0-2 0L4 6.27A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z" />
          <path d="M3.3 7L12 12l8.7-5" />
          <path d="M12 22V12" />
        </svg>
      <% "check" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M20 6 9 17l-5-5" />
        </svg>
      <% "file" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <path d="M14 2v6h6" />
        </svg>
      <% "alert" -> %>
        <svg class={@class} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M10.3 3.6 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.6a2 2 0 0 0-3.4 0Z" />
          <path d="M12 9v4" />
          <path d="M12 17h.01" />
        </svg>
      <% _ -> %>
        <span class={@class} />
    <% end %>
    """
  end

  # ----------------------------
  # Filtering + summary
  # ----------------------------

  defp apply_filters(socket) do
    q = String.downcase(String.trim(socket.assigns.q))
    filter = socket.assigns.filter
    orders_all = socket.assigns.shipped_orders

    counts = %{
      all: length(orders_all),
      delivered: Enum.count(orders_all, &(&1.status == "delivered")),
      awaiting_pod: Enum.count(orders_all, fn o -> not pod_present?(o.pod) end),
      exceptions: Enum.count(orders_all, &exception?/1)
    }

    orders =
      orders_all
      |> Enum.filter(fn o -> matches_query?(o, q) and matches_filter?(o, filter) end)
      |> Enum.sort_by(fn o -> parse_date_days(o.shipment.shipped_date) end, :desc)

    summary = %{
      shipped_count: length(orders_all),
      delivered_count: counts.delivered,
      awaiting_pod_count: counts.awaiting_pod,
      exception_count: counts.exceptions
    }

    socket
    |> assign(:filtered_orders, orders)
    |> assign(:summary, summary)
    |> assign(:counts, counts)
  end

  defp matches_query?(_o, ""), do: true

  defp matches_query?(o, q) do
    hay =
      [
        o.id,
        o.customer,
        o.shipment.carrier,
        o.shipment.tracking_number,
        o.shipment.delivery_note_no,
        o.shipment.consignee
      ]
      |> Enum.map(&String.downcase(to_string(&1 || "")))
      |> Enum.join(" ")

    String.contains?(hay, q)
  end

  defp matches_filter?(o, "awaiting_pod"), do: not pod_present?(o.pod)
  defp matches_filter?(o, "delivered"), do: o.status == "delivered"
  defp matches_filter?(o, "exceptions"), do: exception?(o)
  defp matches_filter?(_o, "all"), do: true

  # ----------------------------
  # Data updates + audit
  # ----------------------------

  defp update_order(socket, order_id, fun) do
    shipped_orders =
      Enum.map(socket.assigns.shipped_orders, fn o ->
        if o.id == order_id, do: fun.(o), else: o
      end)

    selected_order =
      case socket.assigns.selected_order do
        nil -> nil
        o when o.id == order_id -> find_order(shipped_orders, order_id)
        o -> o
      end

    socket
    |> assign(:shipped_orders, shipped_orders)
    |> assign(:selected_order, selected_order)
  end

  defp log_audit(socket, nil, _action, _details), do: socket

  defp log_audit(socket, order_id, action, details) do
    at = now_stamp()
    actor = socket.assigns.user_label
    entry = %{at: at, actor: actor, action: action, details: details}

    audit_by_order_id =
      Map.update(socket.assigns.audit_by_order_id, order_id, [entry], fn list ->
        [entry | list]
      end)

    assign(socket, :audit_by_order_id, audit_by_order_id)
  end

  defp hydrate_pod_form(socket, order) do
    pod = order.pod

    if pod_present?(pod) do
      assign(socket, :pod_form, %{
        "delivered_at" => pod.delivered_at,
        "received_by" => pod.received_by,
        "receiver_id" => pod.receiver_id,
        "notes" => pod.notes
      })
    else
      assign(socket, :pod_form, %{
        "delivered_at" => "",
        "received_by" => "",
        "receiver_id" => "",
        "notes" => ""
      })
    end
  end

  # ----------------------------
  # Helpers
  # ----------------------------

  defp find_order(orders, id), do: Enum.find(orders, &(&1.id == id))

  defp pod_present?(nil), do: false
  defp pod_present?(%{delivered_at: d, received_by: r}), do: present?(d) and present?(r)

  defp present?(v), do: String.trim(to_string(v || "")) != ""

  defp exception?(order) do
    missing_tracking = not present?(order.shipment.tracking_number)
    missing_dn = not present?(order.shipment.delivery_note_no)
    missing_lots = not all_lines_have_lots?(order)
    missing_pod = not pod_present?(order.pod)

    missing_tracking or missing_dn or missing_lots or missing_pod
  end

  defp all_lines_have_lots?(order) do
    Enum.all?(order.lines, fn l -> is_list(l.lots) and l.lots != [] end)
  end

  defp status_badge("delivered"), do: "success"
  defp status_badge("shipped"), do: "neutral"
  defp status_badge(_), do: "warning"

  defp pod_badge(pod) do
    if pod_present?(pod), do: "success", else: "warning"
  end

  defp audit_for(audit_by_order_id, order_id) do
    (Map.get(audit_by_order_id, order_id, []) || [])
    |> Enum.sort_by(fn ev -> ev.at end, :desc)
  end

  defp parse_date_days(iso) do
    case Date.from_iso8601(to_string(iso)) do
      {:ok, d} -> Date.to_gregorian_days(d)
      _ -> 0
    end
  end

  defp now_stamp do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_string()
  end

  defp format_bytes(n) when is_integer(n) and n < 1024, do: "#{n} B"
  defp format_bytes(n) when is_integer(n) and n < 1_048_576, do: "#{Float.round(n / 1024, 1)} KB"
  defp format_bytes(n) when is_integer(n), do: "#{Float.round(n / 1_048_576, 1)} MB"
  defp format_bytes(_), do: "—"

  # ----------------------------
  # Mock data
  # ----------------------------

  defp mock_shipped_orders do
    [
      %{
        id: "SHP-12041",
        customer: "FreshMart SG",
        status: "delivered",
        shipment: %{
          shipped_date: "2025-12-26",
          carrier: "DHL Express",
          service_level: "Express Worldwide",
          tracking_number: "DHL-8891-2201",
          delivery_note_no: "DN-2025-12041",
          movement_ref: "MOVE-78511",
          packed_by: "J.Doe (auto)",
          verified_by: "S.Supervisor",
          consignee: "FreshMart Receiving",
          delivery_address: "Dock 3, FreshMart DC, Singapore"
        },
        lines: [
          %{
            sku_code: "LZ-500",
            sku_name: "Fruit Purée (Chilled)",
            qty: 10,
            uom: "units",
            temp_zone: "chilled",
            lots: [
              %{lot_id: "LOT-089", expiry_date: "2024-12-20", qty: 10}
            ]
          },
          %{
            sku_code: "AP-100",
            sku_name: "Apple Sauce (Ambient)",
            qty: 6,
            uom: "units",
            temp_zone: "ambient",
            lots: [
              %{lot_id: "LOT-201", expiry_date: "2025-01-10", qty: 6}
            ]
          }
        ],
        pod: %{
          delivered_at: "2025-12-27 10:14",
          received_by: "S. Kimani",
          receiver_id: "GatePass-7712",
          notes: "No exceptions noted.",
          files: [%{client_name: "pod_dn-2025-12041.pdf", size: 248_911, type: "application/pdf"}]
        }
      },
      %{
        id: "SHP-12055",
        customer: "GreenGrocer MY",
        status: "shipped",
        shipment: %{
          shipped_date: "2025-12-27",
          carrier: "DHL Express",
          service_level: "Express Worldwide",
          tracking_number: "DHL-8891-3310",
          delivery_note_no: "DN-2025-12055",
          movement_ref: "MOVE-78599",
          packed_by: "A.Njeri",
          verified_by: "S.Supervisor",
          consignee: "GreenGrocer Receiving",
          delivery_address: "Bay 2, GreenGrocer DC, Kuala Lumpur"
        },
        lines: [
          %{
            sku_code: "GR-330",
            sku_name: "Green Blend (Chilled)",
            qty: 5,
            uom: "units",
            temp_zone: "chilled",
            lots: [
              %{lot_id: "LOT-412", expiry_date: "2024-12-22", qty: 4},
              %{lot_id: "LOT-413", expiry_date: "2024-12-29", qty: 1}
            ]
          },
          %{
            sku_code: "LZ-500",
            sku_name: "Fruit Purée (Chilled)",
            qty: 10,
            uom: "units",
            temp_zone: "chilled",
            lots: [
              %{lot_id: "LOT-090", expiry_date: "2024-12-27", qty: 10}
            ]
          }
        ],
        pod: nil
      },
      %{
        id: "SHP-12060",
        customer: "Online Store",
        status: "shipped",
        shipment: %{
          shipped_date: "2025-12-28",
          carrier: "Sendy",
          service_level: "Same-day",
          tracking_number: "SND-5512-8820",
          delivery_note_no: "DN-2025-12060",
          movement_ref: "MOVE-78620",
          packed_by: "J.Doe (auto)",
          verified_by: "M.Manager",
          consignee: "Online Store Dispatch",
          delivery_address: "Customer Drop Hub, Nairobi"
        },
        lines: [
          %{
            sku_code: "BN-210",
            sku_name: "Banana Slices (Frozen)",
            qty: 4,
            uom: "units",
            temp_zone: "frozen",
            lots: [
              %{lot_id: "LOT-311", expiry_date: "2025-02-12", qty: 4}
            ]
          },
          %{
            sku_code: "PK-010",
            sku_name: "Ice Pack (Accessory)",
            qty: 2,
            uom: "units",
            temp_zone: "ambient",
            lots: [
              %{lot_id: "LOT-901", expiry_date: "2026-12-31", qty: 2}
            ]
          }
        ],
        pod: nil
      },
      %{
        id: "SHP-12012",
        customer: "Corner Retail KE",
        status: "shipped",
        shipment: %{
          shipped_date: "2025-12-24",
          carrier: "Rider",
          service_level: "Standard",
          tracking_number: "",
          delivery_note_no: "DN-2025-12012",
          movement_ref: "MOVE-78410",
          packed_by: "A.Njeri",
          verified_by: "",
          consignee: "Corner Retail Backdoor",
          delivery_address: "Ngong Road, Nairobi"
        },
        lines: [
          %{
            sku_code: "AP-100",
            sku_name: "Apple Sauce (Ambient)",
            qty: 8,
            uom: "units",
            temp_zone: "ambient",
            lots: [
              %{lot_id: "LOT-199", expiry_date: "2025-02-01", qty: 8}
            ]
          }
        ],
        pod: nil
      }
    ]
  end

  defp mock_audit_trails(shipped_orders) do
    Map.new(shipped_orders, fn o ->
      base = [
        %{
          at: "#{o.shipment.shipped_date} 09:00:00Z",
          actor: "system",
          action: "shipment.created",
          details:
            "Shipment created; delivery note #{o.shipment.delivery_note_no}; movement #{o.shipment.movement_ref}"
        },
        %{
          at: "#{o.shipment.shipped_date} 09:05:00Z",
          actor: o.shipment.packed_by,
          action: "shipment.packed",
          details: "Packed and sealed; carrier #{o.shipment.carrier}"
        }
      ]

      extra =
        if pod_present?(o.pod) do
          [
            %{
              at: "#{o.shipment.shipped_date} 16:00:00Z",
              actor: "system",
              action: "shipment.delivered",
              details: "Delivered at #{o.pod.delivered_at}; received by #{o.pod.received_by}"
            }
          ]
        else
          []
        end

      {o.id, Enum.reverse(extra) ++ base}
    end)
  end
end
