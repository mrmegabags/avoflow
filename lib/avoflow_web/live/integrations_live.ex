defmodule AvoflowWeb.IntegrationsLive do
  use AvoflowWeb, :live_view

  @tick_ms 5_000

  @tabs [
    %{id: "api-keys", label: "API Keys"},
    %{id: "webhooks", label: "Webhooks"},
    %{id: "event-logs", label: "Event Logs"},
    %{id: "documentation", label: "Documentation"}
  ]

  @available_events [
    "inventory.updated",
    "inventory.reserved",
    "inventory.released",
    "lot.expiring",
    "lot.expired",
    "order.ready_to_pick",
    "order.picked",
    "order.packed",
    "order.fulfilled",
    "hold.created",
    "hold.released",
    "anomaly.detected"
  ]

  # Include wildcards if you show them in sample keys
  @available_key_perms [
    "inventory:read",
    "inventory:write",
    "inventory:*",
    "orders:read",
    "orders:write",
    "orders:*",
    "admin:read"
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Simulate activity for demo: new API calls and occasional webhook deliveries
      :timer.send_interval(@tick_ms, self(), :tick)
    end

    api_keys = seed_api_keys()
    webhooks = seed_webhooks()
    event_logs = seed_event_logs()

    socket =
      socket
      |> assign(
        page_title: "Integrations & API",
        user_label: "Documents E.Impact",
        unread_count: 0,
        q: "",
        tabs: @tabs,
        available_events: @available_events,
        available_key_perms: @available_key_perms,
        active_tab: "api-keys",
        api_keys: api_keys,
        webhooks: webhooks,
        event_logs: event_logs,
        # “Overall” metrics (not necessarily equal to visible sample rows)
        api_calls_24h: 1801,
        metrics_window: seed_metrics_window(400, 0.999),
        show_new_key_modal: false,
        show_new_webhook_modal: false,
        generated_key: nil,
        generated_key_name: nil,
        # Filters
        filter_endpoint: "",
        time_range: "24h",
        status_filter: "all",
        # Form state
        new_key_name: "",
        new_key_permissions: MapSet.new(),
        new_key_ip_whitelist: "",
        new_webhook_url: "",
        new_webhook_events: MapSet.new()
      )
      |> assign_metrics()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) do
    {:noreply,
     if valid_tab?(tab) do
       assign(socket, :active_tab, tab)
     else
       socket
     end}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # --- Demo activity loop ---

  @impl true
  def handle_info(:tick, socket) do
    {log, ok?} = generate_call(socket)

    socket =
      socket
      |> update(:event_logs, fn logs -> [log | logs] |> Enum.take(25) end)
      |> update(:api_calls_24h, &(&1 + 1))
      |> update(:metrics_window, fn window ->
        # keep a rolling success window
        [ok? | window] |> Enum.take(600)
      end)
      |> maybe_tick_webhook(ok?)
      |> assign_metrics()

    {:noreply, socket}
  end

  # --- TopBar no-op handlers (keep assigns stable; you can extend later) ---

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket), do: {:noreply, assign(socket, :q, q)}
  def handle_event("topbar_search", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_profile", _params, socket), do: {:noreply, socket}

  # --- Tabs (keep URL in sync) ---

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply,
     if valid_tab?(tab) do
       socket
       |> assign(:active_tab, tab)
       |> push_patch(to: ~p"/integrations?tab=#{tab}")
     else
       socket
     end}
  end

  # --- API Keys actions ---

  @impl true
  def handle_event("open_new_key_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_new_key_modal: true)
     |> assign(new_key_name: "", new_key_permissions: MapSet.new(), new_key_ip_whitelist: "")}
  end

  def handle_event("close_new_key_modal", _params, socket),
    do: {:noreply, assign(socket, :show_new_key_modal, false)}

  def handle_event("toggle_key_perm", %{"perm" => perm}, socket) do
    perms = socket.assigns.new_key_permissions

    perms =
      if MapSet.member?(perms, perm) do
        MapSet.delete(perms, perm)
      else
        MapSet.put(perms, perm)
      end

    {:noreply, assign(socket, :new_key_permissions, perms)}
  end

  def handle_event("update_new_key", %{"new_key" => params}, socket) do
    {:noreply,
     socket
     |> assign(:new_key_name, Map.get(params, "name", ""))
     |> assign(:new_key_ip_whitelist, Map.get(params, "ip_whitelist", ""))}
  end

  def handle_event("generate_key", _params, socket) do
    name = String.trim(socket.assigns.new_key_name || "")
    perms = socket.assigns.new_key_permissions |> MapSet.to_list() |> Enum.sort()
    ipwl = String.trim(socket.assigns.new_key_ip_whitelist || "")

    with :ok <- validate_required(name, "Key name is required."),
         :ok <- validate_nonempty(perms, "Select at least one permission."),
         :ok <- validate_ip_whitelist(ipwl) do
      secret = generate_secret("sk_live_")

      key = %{
        id: Integer.to_string(System.unique_integer([:positive])),
        name: name,
        key_prefix: String.slice(secret, 0, 10),
        permissions: perms,
        ip_whitelist: ipwl,
        last_used_at: nil,
        created_at: DateTime.utc_now(),
        is_active: true
      }

      {:noreply,
       socket
       |> assign(show_new_key_modal: false, generated_key: secret, generated_key_name: name)
       |> update(:api_keys, fn keys -> [key | keys] end)
       |> put_flash(
         :info,
         "API key generated for #{name}. Copy it now; it will not be shown again."
       )
       |> assign_metrics()}
    else
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg) |> assign(show_new_key_modal: true)}
    end
  end

  def handle_event("close_generated_key", _params, socket),
    do: {:noreply, assign(socket, :generated_key, nil)}

  def handle_event("copy_generated_key", _params, socket) do
    # LiveView-only demo: no JS clipboard hook; we just acknowledge the click.
    {:noreply, put_flash(socket, :info, "Select the key and copy it (LiveView-only demo).")}
  end

  def handle_event("toggle_key_active", %{"id" => id}, socket) do
    api_keys =
      Enum.map(socket.assigns.api_keys, fn k ->
        if k.id == id, do: %{k | is_active: !k.is_active}, else: k
      end)

    {:noreply,
     socket
     |> assign(api_keys: api_keys)
     |> put_flash(:info, "API key status updated.")
     |> assign_metrics()}
  end

  def handle_event("delete_key", %{"id" => id}, socket) do
    api_keys = Enum.reject(socket.assigns.api_keys, &(&1.id == id))

    {:noreply,
     socket
     |> assign(api_keys: api_keys)
     |> put_flash(:info, "API key removed from this demo list.")
     |> assign_metrics()}
  end

  # --- Webhooks actions ---

  def handle_event("open_new_webhook_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_new_webhook_modal: true)
     |> assign(new_webhook_url: "", new_webhook_events: MapSet.new())}
  end

  def handle_event("close_new_webhook_modal", _params, socket),
    do: {:noreply, assign(socket, :show_new_webhook_modal, false)}

  def handle_event("toggle_webhook_event", %{"event" => event}, socket) do
    events = socket.assigns.new_webhook_events

    events =
      if MapSet.member?(events, event) do
        MapSet.delete(events, event)
      else
        MapSet.put(events, event)
      end

    {:noreply, assign(socket, :new_webhook_events, events)}
  end

  def handle_event("update_new_webhook", %{"new_webhook" => params}, socket) do
    {:noreply, assign(socket, :new_webhook_url, Map.get(params, "url", ""))}
  end

  def handle_event("add_webhook", _params, socket) do
    url = socket.assigns.new_webhook_url |> to_string() |> String.trim()
    events = socket.assigns.new_webhook_events |> MapSet.to_list() |> Enum.sort()

    with :ok <- validate_url(url),
         :ok <- validate_nonempty(events, "Select at least one webhook event.") do
      id = Integer.to_string(System.unique_integer([:positive]))

      new_webhook = %{
        id: id,
        url: url,
        events: events,
        is_active: true,
        last_triggered_at: DateTime.utc_now(),
        success_rate: 100.0,
        total_calls: 0
      }

      {:noreply,
       socket
       |> assign(show_new_webhook_modal: false)
       |> update(:webhooks, fn whs -> [new_webhook | whs] end)
       |> put_flash(:info, "Webhook added.")
       |> assign_metrics()}
    else
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg) |> assign(show_new_webhook_modal: true)}
    end
  end

  def handle_event("toggle_webhook_active", %{"id" => id}, socket) do
    webhooks =
      Enum.map(socket.assigns.webhooks, fn w ->
        if w.id == id, do: %{w | is_active: !w.is_active}, else: w
      end)

    {:noreply,
     socket
     |> assign(webhooks: webhooks)
     |> put_flash(:info, "Webhook status updated.")
     |> assign_metrics()}
  end

  def handle_event("delete_webhook", %{"id" => id}, socket) do
    webhooks = Enum.reject(socket.assigns.webhooks, &(&1.id == id))

    {:noreply,
     socket
     |> assign(webhooks: webhooks)
     |> put_flash(:info, "Webhook removed from this demo list.")
     |> assign_metrics()}
  end

  # --- Logs filters + buttons ---

  def handle_event("filter_logs", %{"filters" => params}, socket) do
    {:noreply,
     socket
     |> assign(:filter_endpoint, Map.get(params, "endpoint", ""))
     |> assign(:time_range, Map.get(params, "time_range", "24h"))
     |> assign(:status_filter, Map.get(params, "status_filter", "all"))}
  end

  def handle_event("refresh_logs", _params, socket) do
    {:noreply,
     socket
     |> assign(event_logs: seed_event_logs())
     |> put_flash(:info, "Event log refreshed.")
     |> assign_metrics()}
  end

  def handle_event("export_csv", _params, socket) do
    # Keep LiveView-only: no file streaming hooks here.
    {:noreply,
     put_flash(socket, :info, "CSV export would be handled server-side in a real implementation.")}
  end

  # This fixes the original template bug: phx-click="noop" existed but had no handler.
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    filtered_logs =
      filtered_event_logs(
        assigns.event_logs,
        assigns.filter_endpoint,
        assigns.status_filter,
        assigns.time_range
      )

    ~H"""
    <div class="">
      <main class="">
        <div class="">
          <div class="max-w-7xl mx-auto">
            <.flash_banner flash={@flash} />

            <div class="mb-8">
              <div class="flex items-center space-x-3 mb-2">
                <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center">
                  <span class="w-6 h-6 rounded bg-white/30" aria-hidden="true"></span>
                </div>

                <div>
                  <h1 class="text-2xl font-bold text-gray-900">Integrations &amp; API</h1>
                  <p class="text-gray-500 text-sm">Manage e-commerce integrations and API access</p>
                </div>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
              <div class="p-4 rounded-lg border bg-gradient-to-br from-blue-50 to-blue-100 border-blue-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-blue-600 font-medium mb-1">Active API Keys</p>
                    <p class="text-2xl font-bold text-blue-900">{@active_keys_count}</p>
                  </div>
                  <span class="w-8 h-8 rounded bg-blue-500/20" aria-hidden="true"></span>
                </div>
              </div>

              <div class="p-4 rounded-lg border bg-gradient-to-br from-purple-50 to-purple-100 border-purple-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-purple-600 font-medium mb-1">Webhooks</p>
                    <p class="text-2xl font-bold text-purple-900">{@webhooks_count}</p>
                  </div>
                  <span class="w-8 h-8 rounded bg-purple-500/20" aria-hidden="true"></span>
                </div>
              </div>

              <div class="p-4 rounded-lg border bg-gradient-to-br from-green-50 to-green-100 border-green-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-green-600 font-medium mb-1">API Calls (24h)</p>
                    <p class="text-2xl font-bold text-green-900">{format_int(@api_calls_24h)}</p>
                  </div>
                  <span class="w-8 h-8 rounded bg-green-500/20" aria-hidden="true"></span>
                </div>
              </div>

              <div class="p-4 rounded-lg border bg-gradient-to-br from-orange-50 to-orange-100 border-orange-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs text-orange-600 font-medium mb-1">Success Rate (rolling)</p>
                    <p class="text-2xl font-bold text-orange-900">
                      {format_percent(@success_rate_24h)}
                    </p>
                  </div>
                  <span class="w-8 h-8 rounded bg-orange-500/20" aria-hidden="true"></span>
                </div>
              </div>
            </div>

            <div class="border-b border-gray-200 mb-6">
              <nav class="flex space-x-1">
                <%= for tab <- @tabs do %>
                  <button
                    type="button"
                    phx-click="set_tab"
                    phx-value-tab={tab.id}
                    class={[
                      "flex items-center space-x-2 px-4 py-3 text-sm font-medium transition-all duration-200 border-b-2 -mb-px",
                      tab_class(@active_tab, tab.id)
                    ]}
                  >
                    <span class="w-4 h-4 rounded bg-gray-200" aria-hidden="true"></span>
                    <span>{tab.label}</span>
                  </button>
                <% end %>
              </nav>
            </div>

            <%= if @active_tab == "api-keys" do %>
              <.card title="API Keys">
                <:action>
                  <.btn variant="primary" phx-click="open_new_key_modal">
                    <span class="w-4 h-4 rounded bg-white/20" aria-hidden="true"></span>
                    Generate New Key
                  </.btn>
                </:action>

                <div class="space-y-3">
                  <%= for key <- @api_keys do %>
                    <div class="p-4 border border-gray-200 rounded-lg hover:border-[#2E7D32] hover:shadow-sm transition-all">
                      <div class="flex items-start justify-between mb-3">
                        <div class="flex-1">
                          <div class="flex items-center space-x-3 mb-2">
                            <h4 class="font-semibold text-gray-900">{key.name}</h4>
                            <.badge variant={if(key.is_active, do: "success", else: "neutral")}>
                              {if key.is_active, do: "Active", else: "Inactive"}
                            </.badge>
                          </div>

                          <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-500">
                            <span class="flex items-center space-x-1">
                              <span class="w-3 h-3 rounded bg-gray-200" aria-hidden="true"></span>
                              <span class="font-mono">{key.key_prefix}••••••••</span>
                            </span>

                            <span class="flex items-center space-x-1">
                              <span class="w-3 h-3 rounded bg-gray-200" aria-hidden="true"></span>
                              <span>
                                Last used: {if key.last_used_at,
                                  do: relative_time(key.last_used_at),
                                  else: "never"}
                              </span>
                            </span>

                            <span class="flex items-center space-x-1">
                              <span>Created: {format_dt(key.created_at)}</span>
                            </span>

                            <%= if key.ip_whitelist && key.ip_whitelist != "" do %>
                              <span class="flex items-center space-x-1">
                                <span class="w-3 h-3 rounded bg-gray-200" aria-hidden="true"></span>
                                <span class="font-mono">IP: {key.ip_whitelist}</span>
                              </span>
                            <% end %>
                          </div>
                        </div>

                        <div class="flex items-center space-x-2">
                          <.btn
                            variant="ghost"
                            type="button"
                            phx-click="toggle_key_active"
                            phx-value-id={key.id}
                            title="Toggle active"
                          >
                            <span class="w-4 h-4 rounded bg-gray-200" aria-hidden="true"></span>
                          </.btn>

                          <.btn
                            variant="ghost"
                            type="button"
                            phx-click="delete_key"
                            phx-value-id={key.id}
                            title="Delete"
                          >
                            <span class="w-4 h-4 rounded bg-red-200" aria-hidden="true"></span>
                          </.btn>
                        </div>
                      </div>

                      <div class="flex flex-wrap gap-1.5">
                        <%= for perm <- key.permissions do %>
                          <span class="px-2 py-0.5 bg-gray-100 text-gray-700 text-xs rounded-full font-mono">
                            {perm}
                          </span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                  <div class="flex items-start space-x-3">
                    <span
                      class="w-5 h-5 rounded bg-blue-600/20 flex-shrink-0 mt-0.5"
                      aria-hidden="true"
                    >
                    </span>
                    <div class="text-sm text-blue-900">
                      <p class="font-medium mb-1">Security Best Practices</p>
                      <ul class="text-blue-800 space-y-1 text-xs">
                        <li>• Store keys in a secrets manager (or env vars for local dev)</li>
                        <li>• Rotate keys regularly (e.g., every 90 days)</li>
                        <li>• Restrict permissions (least privilege)</li>
                        <li>• Consider IP allowlisting for production</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </.card>
            <% end %>

            <%= if @active_tab == "webhooks" do %>
              <.card title="Webhook Subscriptions">
                <:action>
                  <.btn variant="primary" phx-click="open_new_webhook_modal">
                    <span class="w-4 h-4 rounded bg-white/20" aria-hidden="true"></span> Add Webhook
                  </.btn>
                </:action>

                <div class="space-y-4">
                  <%= for webhook <- @webhooks do %>
                    <div class="p-4 border border-gray-200 rounded-lg hover:border-purple-300 hover:shadow-sm transition-all">
                      <div class="flex items-start justify-between mb-3">
                        <div class="flex-1">
                          <div class="flex flex-wrap items-center gap-x-3 gap-y-2 mb-2">
                            <code class="text-sm font-mono text-gray-900 bg-gray-100 px-2 py-1 rounded">
                              {webhook.url}
                            </code>

                            <.badge variant={if(webhook.is_active, do: "success", else: "neutral")}>
                              {if webhook.is_active, do: "Active", else: "Paused"}
                            </.badge>
                          </div>

                          <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-500">
                            <span class="flex items-center space-x-1">
                              <span class="w-3 h-3 rounded bg-gray-200" aria-hidden="true"></span>
                              <span>
                                Last triggered: {if webhook.last_triggered_at,
                                  do: relative_time(webhook.last_triggered_at),
                                  else: "never"}
                              </span>
                            </span>

                            <span class="flex items-center space-x-1">
                              <span class="w-3 h-3 rounded bg-green-600/20" aria-hidden="true"></span>
                              <span>Success rate: {format_percent(webhook.success_rate)}</span>
                            </span>

                            <span>({format_int(webhook.total_calls)} calls)</span>
                          </div>
                        </div>

                        <div class="flex items-center space-x-2">
                          <.btn
                            variant="ghost"
                            type="button"
                            phx-click="toggle_webhook_active"
                            phx-value-id={webhook.id}
                            title="Pause/Resume"
                          >
                            <span class="w-4 h-4 rounded bg-gray-200" aria-hidden="true"></span>
                          </.btn>

                          <.btn
                            variant="ghost"
                            type="button"
                            phx-click="delete_webhook"
                            phx-value-id={webhook.id}
                            title="Delete"
                          >
                            <span class="w-4 h-4 rounded bg-red-200" aria-hidden="true"></span>
                          </.btn>
                        </div>
                      </div>

                      <div>
                        <p class="text-xs text-gray-600 mb-2">Subscribed Events:</p>
                        <div class="flex flex-wrap gap-1.5">
                          <%= for event <- webhook.events do %>
                            <span class="px-2 py-0.5 bg-purple-100 text-purple-700 text-xs rounded-full font-mono">
                              {event}
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="mt-6">
                  <h4 class="text-sm font-semibold text-gray-900 mb-3">Available Events</h4>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <%= for event <- @available_events do %>
                      <div class="p-2 bg-gray-50 border border-gray-200 rounded text-xs font-mono text-gray-700">
                        {event}
                      </div>
                    <% end %>
                  </div>
                </div>
              </.card>
            <% end %>

            <%= if @active_tab == "event-logs" do %>
              <.card title="API Event Logs">
                <:action>
                  <div class="flex items-center space-x-2">
                    <.btn variant="secondary" type="button" phx-click="export_csv">
                      <span class="w-4 h-4 rounded bg-gray-300" aria-hidden="true"></span> Export CSV
                    </.btn>
                    <.btn variant="secondary" type="button" phx-click="refresh_logs">
                      <span class="w-4 h-4 rounded bg-gray-300" aria-hidden="true"></span> Refresh
                    </.btn>
                  </div>
                </:action>

                <form
                  phx-change="filter_logs"
                  class="mb-4 flex flex-col sm:flex-row sm:items-center gap-3"
                >
                  <input
                    type="text"
                    name="filters[endpoint]"
                    value={@filter_endpoint}
                    placeholder="Filter by endpoint..."
                    class="h-10 px-3 border border-gray-300 rounded-md text-sm w-full sm:max-w-xs focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                  />

                  <select
                    name="filters[time_range]"
                    class="h-10 px-3 border border-gray-300 rounded-md text-sm w-full sm:w-auto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                  >
                    <option value="24h" selected={@time_range == "24h"}>Last 24 hours</option>
                    <option value="7d" selected={@time_range == "7d"}>Last 7 days</option>
                    <option value="30d" selected={@time_range == "30d"}>Last 30 days</option>
                  </select>

                  <select
                    name="filters[status_filter]"
                    class="h-10 px-3 border border-gray-300 rounded-md text-sm w-full sm:w-auto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                  >
                    <option value="all" selected={@status_filter == "all"}>All Status</option>
                    <option value="2xx" selected={@status_filter == "2xx"}>Success (2xx)</option>
                    <option value="4xx" selected={@status_filter == "4xx"}>Client Error (4xx)</option>
                    <option value="5xx" selected={@status_filter == "5xx"}>Server Error (5xx)</option>
                  </select>
                </form>

                <div class="border rounded-lg overflow-hidden overflow-x-auto">
                  <table class="w-full text-sm min-w-[860px]">
                    <thead class="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th class="text-left py-3 px-4 font-semibold text-gray-700">Timestamp</th>
                        <th class="text-left py-3 px-4 font-semibold text-gray-700">Method</th>
                        <th class="text-left py-3 px-4 font-semibold text-gray-700">Endpoint</th>
                        <th class="text-left py-3 px-4 font-semibold text-gray-700">Key</th>
                        <th class="text-left py-3 px-4 font-semibold text-gray-700">Status</th>
                        <th class="text-right py-3 px-4 font-semibold text-gray-700">Duration</th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-gray-100">
                      <%= for log <- filtered_logs do %>
                        <tr class="hover:bg-gray-50">
                          <td class="py-3 px-4 text-gray-600 font-mono text-xs">
                            {format_dt(log.at, :with_seconds)}
                          </td>

                          <td class="py-3 px-4">
                            <span class={[
                              "px-2 py-0.5 rounded text-xs font-semibold",
                              method_class(log.method)
                            ]}>
                              {log.method}
                            </span>
                          </td>

                          <td class="py-3 px-4 font-mono text-xs text-gray-700">{log.endpoint}</td>
                          <td class="py-3 px-4 font-mono text-xs text-gray-500">{log.key}</td>

                          <td class="py-3 px-4">
                            <.badge variant={status_variant(log.status)}>{log.status}</.badge>
                          </td>

                          <td class="py-3 px-4 text-right text-gray-600 font-mono text-xs">
                            {"#{log.duration_ms}ms"}
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>

                <div class="mt-4 flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3 text-sm text-gray-600">
                  <span>
                    Showing {length(filtered_logs)} of {length(@event_logs)} sampled events
                    ({@time_range} filter)
                  </span>
                </div>
              </.card>
            <% end %>

            <%= if @active_tab == "documentation" do %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <.card title="Quick Start">
                  <div class="space-y-4">
                    <div>
                      <h4 class="text-sm font-semibold text-gray-900 mb-2">1. Generate API Key</h4>
                      <p class="text-sm text-gray-600">
                        Create a new API key with only the permissions needed for your integration.
                      </p>
                    </div>

                    <div>
                      <h4 class="text-sm font-semibold text-gray-900 mb-2">
                        2. Authenticate Requests
                      </h4>
                      <div class="bg-gray-900 text-gray-100 p-3 rounded-lg font-mono text-xs overflow-x-auto">
                        <code>Authorization: Bearer sk_live_...</code>
                      </div>
                    </div>

                    <div>
                      <h4 class="text-sm font-semibold text-gray-900 mb-2">3. Make API Calls</h4>
                      <div class="bg-gray-900 text-gray-100 p-3 rounded-lg font-mono text-xs overflow-x-auto">
                        <code>GET /api/v1/inventory/atp</code>
                      </div>
                    </div>
                  </div>
                </.card>

                <.card title="Core Endpoints">
                  <div class="space-y-3">
                    <%= for ep <- core_endpoints() do %>
                      <div class="p-3 bg-gray-50 border border-gray-200 rounded-lg">
                        <div class="flex items-center space-x-2 mb-1">
                          <span class={[
                            "px-2 py-0.5 rounded text-xs font-semibold",
                            method_class(ep.method)
                          ]}>
                            {ep.method}
                          </span>
                          <code class="text-xs font-mono text-gray-700">{ep.path}</code>
                        </div>
                        <p class="text-xs text-gray-600">{ep.desc}</p>
                      </div>
                    <% end %>
                  </div>
                </.card>

                <.card title="Rate Limits (example)">
                  <div class="space-y-3">
                    <div class="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                      <span class="text-sm text-gray-700">Requests per minute</span>
                      <span class="text-sm font-semibold text-gray-900">1,000</span>
                    </div>
                    <div class="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                      <span class="text-sm text-gray-700">Requests per hour</span>
                      <span class="text-sm font-semibold text-gray-900">10,000</span>
                    </div>
                    <div class="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                      <span class="text-sm text-gray-700">Burst limit</span>
                      <span class="text-sm font-semibold text-gray-900">100 / 10s</span>
                    </div>
                  </div>
                </.card>

                <.card title="Webhook Security (example)">
                  <div class="space-y-3 text-sm text-gray-600">
                    <p>All webhook payloads are signed with HMAC-SHA256.</p>
                    <div class="bg-gray-900 text-gray-100 p-3 rounded-lg font-mono text-xs overflow-x-auto">
                      <code>X-Webhook-Signature: sha256=...</code>
                    </div>
                    <p class="text-xs">
                      Verify the signature using your webhook secret to ensure requests are authentic.
                    </p>
                  </div>
                </.card>
              </div>
            <% end %>

            <%= if @show_new_key_modal do %>
              <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
                <div class="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4">
                  <div class="p-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-4">Generate New API Key</h3>

                    <form
                      phx-change="update_new_key"
                      phx-submit="generate_key"
                      class="space-y-4"
                      autocomplete="off"
                    >
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Key Name</label>
                        <input
                          type="text"
                          name="new_key[name]"
                          value={@new_key_name}
                          placeholder="e.g., Production Shopify Store"
                          class="w-full h-10 px-3 border border-gray-300 rounded-md text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">
                          Permissions
                        </label>
                        <div class="space-y-2">
                          <%= for perm <- @available_key_perms do %>
                            <% perm_dom_id = dom_id_from_value("perm-" <> perm) %>
                            <label class="flex items-center space-x-2" for={perm_dom_id}>
                              <input
                                id={perm_dom_id}
                                type="checkbox"
                                checked={MapSet.member?(@new_key_permissions, perm)}
                                phx-click="toggle_key_perm"
                                phx-value-perm={perm}
                                class="rounded text-[#2E7D32] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                              />
                              <span class="text-sm text-gray-700 font-mono">{perm}</span>
                            </label>
                          <% end %>
                        </div>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">
                          IP Whitelist (optional)
                        </label>
                        <input
                          type="text"
                          name="new_key[ip_whitelist]"
                          value={@new_key_ip_whitelist}
                          placeholder="203.0.113.0/24"
                          class="w-full h-10 px-3 border border-gray-300 rounded-md text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        />
                        <p class="text-xs text-gray-500 mt-1">
                          For demo: accepts empty, IPv4, or IPv4/CIDR.
                        </p>
                      </div>

                      <div class="flex justify-end space-x-3 mt-6">
                        <.btn variant="secondary" type="button" phx-click="close_new_key_modal">
                          Cancel
                        </.btn>
                        <.btn variant="primary" type="submit">Generate Key</.btn>
                      </div>
                    </form>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @show_new_webhook_modal do %>
              <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
                <div class="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4">
                  <div class="p-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-4">Add Webhook</h3>

                    <form
                      phx-change="update_new_webhook"
                      phx-submit="add_webhook"
                      class="space-y-4"
                      autocomplete="off"
                    >
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">
                          Webhook URL
                        </label>
                        <input
                          type="url"
                          name="new_webhook[url]"
                          value={@new_webhook_url}
                          placeholder="https://example.com/webhooks/inventory"
                          class="w-full h-10 px-3 border border-gray-300 rounded-md text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Events</label>
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                          <%= for event <- @available_events do %>
                            <% event_dom_id = dom_id_from_value("evt-" <> event) %>
                            <label class="flex items-center space-x-2" for={event_dom_id}>
                              <input
                                id={event_dom_id}
                                type="checkbox"
                                checked={MapSet.member?(@new_webhook_events, event)}
                                phx-click="toggle_webhook_event"
                                phx-value-event={event}
                                class="rounded text-[#2E7D32] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2"
                              />
                              <span class="text-xs text-gray-700 font-mono">{event}</span>
                            </label>
                          <% end %>
                        </div>
                      </div>

                      <div class="flex justify-end space-x-3 mt-6">
                        <.btn variant="secondary" type="button" phx-click="close_new_webhook_modal">
                          Cancel
                        </.btn>
                        <.btn variant="primary" type="submit">Add Webhook</.btn>
                      </div>
                    </form>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @generated_key do %>
              <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
                <div class="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4">
                  <div class="p-6">
                    <div class="flex items-center space-x-3 mb-4">
                      <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
                        <span class="w-6 h-6 rounded bg-green-600/20" aria-hidden="true"></span>
                      </div>
                      <div>
                        <h3 class="text-lg font-semibold text-gray-900">API Key Generated</h3>
                        <p class="text-xs text-gray-500">{@generated_key_name || "New key"}</p>
                      </div>
                    </div>

                    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                      <p class="text-sm text-yellow-900 font-medium mb-2">
                        ⚠️ Copy this key now. It will not be shown again.
                      </p>

                      <div class="flex flex-col sm:flex-row sm:items-center gap-2">
                        <code class="flex-1 bg-white border border-yellow-300 rounded px-3 py-2 text-sm font-mono text-gray-900 break-all">
                          {@generated_key}
                        </code>

                        <.btn variant="secondary" type="button" phx-click="copy_generated_key">
                          <span class="w-4 h-4 rounded bg-gray-300" aria-hidden="true"></span>
                        </.btn>
                      </div>

                      <p class="text-xs text-yellow-900 mt-2">
                        LiveView-only demo: clipboard copy is not implemented (no JS hook).
                      </p>
                    </div>

                    <div class="text-sm text-gray-600 space-y-2">
                      <p class="font-medium">Next Steps:</p>
                      <ol class="list-decimal list-inside space-y-1 text-xs">
                        <li>Store this key securely (env var / secrets manager)</li>
                        <li>Use in Authorization header: Authorization: Bearer sk_live_...</li>
                        <li>Test with GET /api/v1/inventory/skus</li>
                      </ol>
                    </div>

                    <div class="flex justify-end mt-6">
                      <.btn variant="primary" type="button" phx-click="close_generated_key">
                        Close
                      </.btn>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # --- Components (function components only) ---

  attr :title, :string, default: nil
  attr :class, :string, default: ""
  slot :action
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <section class={["bg-white border border-gray-200 rounded-lg shadow-sm", @class]}>
      <div
        :if={@title || @action != []}
        class="flex items-center justify-between px-6 py-4 border-b border-gray-100"
      >
        <h2 :if={@title} class="text-sm font-semibold text-gray-900">{@title}</h2>
        <div :if={@action != []}>{render_slot(@action)}</div>
      </div>
      <div class="p-6">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :variant, :string, default: "primary"
  attr :class, :string, default: ""
  attr :type, :string, default: "button"
  attr :rest, :global
  slot :inner_block, required: true

  def btn(assigns) do
    base =
      "inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium transition-colors " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
        "disabled:pointer-events-none disabled:opacity-50"

    variant =
      case assigns.variant do
        "secondary" -> "bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm hover:bg-gray-200"
        "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"
        _ -> "bg-[#2E7D32] text-white rounded-full h-9 px-4 text-sm hover:bg-[#256628]"
      end

    assigns = assign(assigns, :classes, [base, variant, assigns.class])

    ~H"""
    <button type={@type} class={@classes} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :variant, :string, default: "neutral"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    base = "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold"

    variant =
      case assigns.variant do
        "success" -> "bg-green-100 text-green-700"
        "danger" -> "bg-red-100 text-red-700"
        _ -> "bg-gray-100 text-gray-700"
      end

    ~H"""
    <span class={[base, variant, @class]}>{render_slot(@inner_block)}</span>
    """
  end

  attr :flash, :map, required: true

  def flash_banner(assigns) do
    info = Phoenix.Flash.get(assigns.flash, :info)
    error = Phoenix.Flash.get(assigns.flash, :error)

    assigns =
      assigns
      |> assign(:info, info)
      |> assign(:error, error)

    ~H"""
    <div class="mb-4 space-y-2">
      <div
        :if={@info}
        class="p-3 rounded-lg border border-green-200 bg-green-50 text-green-800 text-sm"
      >
        {@info}
      </div>
      <div :if={@error} class="p-3 rounded-lg border border-red-200 bg-red-50 text-red-800 text-sm">
        {@error}
      </div>
    </div>
    """
  end

  # --- Helpers ---

  defp valid_tab?(tab), do: tab in Enum.map(@tabs, & &1.id)

  defp tab_class(active, id) do
    if active == id do
      "border-[#2E7D32] text-[#2E7D32]"
    else
      "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end

  defp method_class("GET"), do: "bg-blue-100 text-blue-700"
  defp method_class(_), do: "bg-green-100 text-green-700"

  defp status_variant(status) when is_integer(status) and status >= 200 and status < 300,
    do: "success"

  defp status_variant(status) when is_integer(status) and status >= 400 and status < 600,
    do: "danger"

  defp status_variant(_), do: "neutral"

  defp filtered_event_logs(event_logs, endpoint_filter, status_filter, time_range) do
    endpoint_filter = String.downcase(String.trim(endpoint_filter || ""))
    cutoff = cutoff_dt(time_range)

    event_logs
    |> Enum.filter(fn log ->
      endpoint_ok =
        if endpoint_filter == "" do
          true
        else
          String.contains?(String.downcase(log.endpoint), endpoint_filter)
        end

      status_ok =
        case status_filter do
          "2xx" -> log.status >= 200 and log.status < 300
          "4xx" -> log.status >= 400 and log.status < 500
          "5xx" -> log.status >= 500 and log.status < 600
          _ -> true
        end

      time_ok =
        case cutoff do
          nil -> true
          %DateTime{} -> DateTime.compare(log.at, cutoff) != :lt
        end

      endpoint_ok and status_ok and time_ok
    end)
  end

  defp cutoff_dt("24h"), do: DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
  defp cutoff_dt("7d"), do: DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
  defp cutoff_dt("30d"), do: DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)
  defp cutoff_dt(_), do: nil

  defp assign_metrics(socket) do
    active_keys_count = Enum.count(socket.assigns.api_keys, & &1.is_active)
    webhooks_count = length(socket.assigns.webhooks)

    window = socket.assigns.metrics_window || []

    success_rate =
      case window do
        [] ->
          100.0

        _ ->
          ok = Enum.count(window, & &1)
          ok / length(window) * 100
      end

    assign(socket,
      active_keys_count: active_keys_count,
      webhooks_count: webhooks_count,
      success_rate_24h: success_rate
    )
  end

  defp format_dt(%DateTime{} = dt, :with_seconds) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_dt(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d")
  end

  defp relative_time(%DateTime{} = dt) do
    sec = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      sec < 0 -> "just now"
      sec < 60 -> "#{sec}s ago"
      sec < 3600 -> "#{div(sec, 60)}m ago"
      sec < 86_400 -> "#{div(sec, 3600)}h ago"
      true -> "#{div(sec, 86_400)}d ago"
    end
  end

  defp core_endpoints do
    [
      %{method: "GET", path: "/api/v1/inventory/skus", desc: "List all packaging SKUs"},
      %{method: "GET", path: "/api/v1/inventory/atp", desc: "Get available-to-promise stock"},
      %{method: "POST", path: "/api/v1/orders/reserve", desc: "Reserve stock for order"},
      %{method: "POST", path: "/api/v1/orders/confirm", desc: "Confirm order allocation"},
      %{method: "POST", path: "/api/v1/orders/fulfill", desc: "Mark order as fulfilled"},
      %{method: "POST", path: "/api/v1/orders/cancel", desc: "Cancel order and release stock"}
    ]
  end

  defp format_int(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map_join(",", &Enum.join/1)
  end

  defp format_int(n) when is_binary(n), do: n
  defp format_int(n), do: to_string(n)

  defp format_percent(n) when is_integer(n), do: "#{n}%"

  defp format_percent(n) when is_float(n) do
    s = :erlang.float_to_binary(n, decimals: 1)
    s = if String.ends_with?(s, ".0"), do: String.trim_trailing(s, ".0"), else: s
    s <> "%"
  end

  defp format_percent(n), do: "#{n}%"

  defp dom_id_from_value(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-_]+/u, "-")
    |> String.trim("-")
  end

  # --- Validation ---

  defp validate_required(v, msg) when is_binary(v) do
    if String.trim(v) == "", do: {:error, msg}, else: :ok
  end

  defp validate_nonempty(list, msg) when is_list(list) do
    if list == [], do: {:error, msg}, else: :ok
  end

  defp validate_url(url) do
    uri = URI.parse(url)

    cond do
      url == "" ->
        {:error, "Webhook URL is required."}

      uri.scheme not in ["http", "https"] ->
        {:error, "Webhook URL must start with http:// or https://"}

      is_nil(uri.host) ->
        {:error, "Webhook URL must include a valid host."}

      true ->
        :ok
    end
  end

  # Demo-only: accept "", IPv4, or IPv4/CIDR (lightweight, avoids heavy parsing)
  defp validate_ip_whitelist(""), do: :ok

  defp validate_ip_whitelist(ip) do
    ok? =
      ip =~ ~r/^\d{1,3}(\.\d{1,3}){3}(\/\d{1,2})?$/ and
        Enum.all?(String.split(ip, [".", "/"], trim: true), fn part ->
          case Integer.parse(part) do
            {n, ""} -> n >= 0 and n <= 255
            _ -> false
          end
        end)

    if ok?,
      do: :ok,
      else: {:error, "IP whitelist must be empty, IPv4, or IPv4/CIDR (demo validation)."}
  end

  # --- Demo data seeds ---

  defp seed_api_keys do
    now = DateTime.utc_now()

    [
      %{
        id: "1",
        name: "Shopify Store (Production)",
        key_prefix: "sk_live_AbC",
        permissions: ["inventory:read", "orders:write"],
        ip_whitelist: "203.0.113.0/24",
        last_used_at: DateTime.add(now, -2 * 60, :second),
        created_at: DateTime.add(now, -80 * 86_400, :second),
        is_active: true
      },
      %{
        id: "2",
        name: "WooCommerce (Production)",
        key_prefix: "sk_live_CdE",
        permissions: ["inventory:read", "orders:write"],
        ip_whitelist: "",
        last_used_at: DateTime.add(now, -3600, :second),
        created_at: DateTime.add(now, -90 * 86_400, :second),
        is_active: true
      },
      %{
        id: "3",
        name: "Internal Dashboard (Staging)",
        key_prefix: "sk_test_EfG",
        permissions: ["inventory:*", "orders:*", "admin:read"],
        ip_whitelist: "",
        last_used_at: DateTime.add(now, -5 * 60, :second),
        created_at: DateTime.add(now, -100 * 86_400, :second),
        is_active: true
      }
    ]
  end

  defp seed_webhooks do
    now = DateTime.utc_now()

    [
      %{
        id: "1",
        url: "https://shop.example.com/webhooks/inventory",
        events: ["inventory.updated", "lot.expiring", "order.fulfilled"],
        is_active: true,
        last_triggered_at: DateTime.add(now, -2 * 60, :second),
        success_rate: 99.8,
        total_calls: 1234
      },
      %{
        id: "2",
        url: "https://erp.example.com/api/stock",
        events: ["inventory.updated", "hold.created"],
        is_active: true,
        last_triggered_at: DateTime.add(now, -5 * 60, :second),
        success_rate: 100.0,
        total_calls: 567
      }
    ]
  end

  defp seed_event_logs do
    now = DateTime.utc_now()

    [
      %{
        at: DateTime.add(now, -10, :second),
        method: "GET",
        endpoint: "/api/v1/inventory/atp",
        key: "sk_...AbC",
        status: 200,
        duration_ms: 45
      },
      %{
        at: DateTime.add(now, -25, :second),
        method: "POST",
        endpoint: "/api/v1/orders/reserve",
        key: "sk_...AbC",
        status: 201,
        duration_ms: 120
      },
      %{
        at: DateTime.add(now, -40, :second),
        method: "GET",
        endpoint: "/api/v1/inventory/skus",
        key: "sk_...CdE",
        status: 200,
        duration_ms: 32
      },
      %{
        at: DateTime.add(now, -60, :second),
        method: "POST",
        endpoint: "/api/v1/orders/confirm",
        key: "sk_...AbC",
        status: 201,
        duration_ms: 250
      },
      %{
        at: DateTime.add(now, -95, :second),
        method: "GET",
        endpoint: "/api/v1/lots/expiring",
        key: "sk_...EfG",
        status: 200,
        duration_ms: 78
      },
      %{
        at: DateTime.add(now, -130, :second),
        method: "POST",
        endpoint: "/api/v1/orders/fulfill",
        key: "sk_...AbC",
        status: 200,
        duration_ms: 180
      },
      %{
        at: DateTime.add(now, -180, :second),
        method: "GET",
        endpoint: "/api/v1/inventory/atp",
        key: "sk_...CdE",
        status: 429,
        duration_ms: 5
      }
    ]
  end

  defp seed_metrics_window(n, success_ratio) when n > 0 do
    # Approximate ratio without extra deps
    ok_count = trunc(n * success_ratio)
    bad_count = max(n - ok_count, 0)
    List.duplicate(true, ok_count) ++ List.duplicate(false, bad_count)
  end

  # --- Demo call generator ---

  defp generate_call(socket) do
    now = DateTime.utc_now()

    endpoints = [
      {"GET", "/api/v1/inventory/atp"},
      {"GET", "/api/v1/inventory/skus"},
      {"POST", "/api/v1/orders/reserve"},
      {"POST", "/api/v1/orders/confirm"},
      {"POST", "/api/v1/orders/fulfill"},
      {"GET", "/api/v1/lots/expiring"}
    ]

    {method, endpoint} = Enum.random(endpoints)

    key =
      socket.assigns.api_keys
      |> Enum.filter(& &1.is_active)
      |> Enum.map(&("sk_..." <> String.slice(&1.key_prefix, -3..-1)))
      |> case do
        [] -> "sk_...N/A"
        keys -> Enum.random(keys)
      end

    # Mostly success; occasional 429 or 500 to keep the UI interesting
    r = :rand.uniform(1000)

    {status, ok?} =
      cond do
        r <= 6 -> {500, false}
        r <= 20 -> {429, false}
        method == "POST" -> {201, true}
        true -> {200, true}
      end

    dur =
      case status do
        429 -> Enum.random(3..12)
        500 -> Enum.random(120..420)
        _ -> Enum.random(18..260)
      end

    {%{at: now, method: method, endpoint: endpoint, key: key, status: status, duration_ms: dur},
     ok?}
  end

  defp maybe_tick_webhook(socket, ok?) do
    # Occasionally increment webhook counters; keep it light
    if :rand.uniform(5) == 1 do
      now = DateTime.utc_now()

      webhooks =
        Enum.map(socket.assigns.webhooks, fn w ->
          if w.is_active do
            total_calls = w.total_calls + 1
            # simple: success rate drifts slightly
            success_rate = clamp_rate(w.success_rate + if(ok?, do: 0.02, else: -0.3))
            %{w | total_calls: total_calls, last_triggered_at: now, success_rate: success_rate}
          else
            w
          end
        end)

      assign(socket, webhooks: webhooks)
    else
      socket
    end
  end

  defp clamp_rate(r) when is_float(r) do
    cond do
      r < 0.0 -> 0.0
      r > 100.0 -> 100.0
      true -> r
    end
  end

  # --- Secrets ---

  defp generate_secret(prefix) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    prefix <> token
  end
end
