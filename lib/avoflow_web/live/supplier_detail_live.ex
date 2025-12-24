defmodule AvoflowWeb.SupplierDetailLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar
  import Phoenix.Component

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Mock data — replace with DB lookup by id later
    supplier = %{
      id: id,
      name: "Avocorp International",
      contact_name: "John Doe",
      phone: "+254 712 345 678",
      email: "orders@avocorp.com",
      address: "123 Farm Road, Highlands",
      weekly_volume: 80,
      avg_ripening_days: 3,
      status: "Active",
      default_variety: "Hass",
      ratings: %{
        delivery: 4.5,
        quality: 4.0,
        ripeness: 4.2,
        reliability: 4.7
      }
    }

    {:ok,
     assign(socket,
       page_title: "Supplier",
       q: "",
       user_label: "User",
       unread_count: 0,
       supplier: supplier
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="">
      <div class="">
        <!-- Back -->
        <.link
          navigate={~p"/suppliers"}
          class="inline-flex items-center text-sm text-gray-500 hover:text-gray-900 mb-4 transition-colors"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-4 h-4 mr-1"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
          Back to Suppliers
        </.link>
        
    <!-- Header -->
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-4 mb-6">
          <div>
            <div class="flex items-center gap-3 mb-1">
              <h1 class="text-2xl font-bold text-gray-900">{@supplier.name}</h1>
              <.status_badge status={@supplier.status} />
            </div>
            <p class="text-gray-500">Supplier ID: #{@supplier.id}</p>
          </div>

          <div class="flex flex-row gap-3 sm:justify-end">
            <button
              type="button"
              phx-click="deactivate"
              class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-full text-sm font-medium
                     bg-red-600 text-white hover:bg-red-700
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-red-500/30"
            >
              <!-- Ban icon -->
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="4.9" y1="4.9" x2="19.1" y2="19.1"></line>
              </svg>
              Deactivate
            </button>

            <button
              type="button"
              phx-click="edit"
              class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-full text-sm font-medium
                     bg-gray-100 text-gray-900 hover:bg-gray-200
                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
            >
              <!-- Edit icon -->
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="w-4 h-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path d="M12 20h9"></path>
                <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"></path>
              </svg>
              Edit Details
            </button>
          </div>
        </div>
        
    <!-- Content -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Left -->
          <div class="lg:col-span-2 space-y-6">
            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Company Information</h3>
              </div>

              <div class="p-5">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Primary Contact</h4>
                    <p class="text-gray-900 font-medium">{@supplier.contact_name}</p>
                  </div>

                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Default Variety</h4>
                    <p class="text-gray-900">{@supplier.default_variety}</p>
                  </div>

                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Contact Details</h4>
                    <div class="space-y-1">
                      <div class="flex items-center text-sm text-gray-600">
                        <.mini_icon name="phone" />
                        <span>{@supplier.phone}</span>
                      </div>
                      <div class="flex items-center text-sm text-gray-600">
                        <.mini_icon name="mail" />
                        <span>{@supplier.email}</span>
                      </div>
                      <div class="flex items-center text-sm text-gray-600">
                        <.mini_icon name="map" />
                        <span>{@supplier.address}</span>
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4 class="text-sm font-medium text-gray-500 mb-1">Performance Metrics</h4>
                    <div class="space-y-1">
                      <p class="text-sm text-gray-600">
                        Weekly Volume:
                        <span class="font-medium text-gray-900">{@supplier.weekly_volume} kg</span>
                      </p>
                      <p class="text-sm text-gray-600">
                        Avg Ripening:
                        <span class="font-medium text-gray-900">
                          {@supplier.avg_ripening_days} days
                        </span>
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </section>

            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Recent Deliveries</h3>
              </div>
              <div class="p-5">
                <div class="text-center py-8 text-gray-500">
                  Table of recent batches would go here...
                </div>
              </div>
            </section>
          </div>
          
    <!-- Right: Scorecard -->
          <div class="lg:col-span-1">
            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Supplier Scorecard</h3>
              </div>

              <div class="p-5">
                <.score_summary ratings={@supplier.ratings} />

                <div class="space-y-1">
                  <.rating_row
                    label="Delivery Consistency"
                    value={@supplier.ratings.delivery}
                    icon="truck"
                  />
                  <.rating_row
                    label="Quality Standards"
                    value={@supplier.ratings.quality}
                    icon="shield"
                  />
                  <.rating_row
                    label="Ripeness Accuracy"
                    value={@supplier.ratings.ripeness}
                    icon="clock"
                  />
                  <.rating_row
                    label="Overall Reliability"
                    value={@supplier.ratings.reliability}
                    icon="trend"
                  />
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>
    </main>
    """
  end

  # --------------------
  # Events (simple no-ops)
  # --------------------
  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket), do: {:noreply, assign(socket, :q, q)}
  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  def handle_event("deactivate", _params, socket), do: {:noreply, socket}
  def handle_event("edit", _params, socket), do: {:noreply, socket}

  # --------------------
  # Small components
  # --------------------
  attr :status, :string, required: true

  def status_badge(assigns) do
    {cls, label} =
      case assigns.status do
        "Active" -> {"bg-green-50 text-green-700 ring-green-600/20", "Active"}
        _ -> {"bg-gray-50 text-gray-700 ring-gray-600/20", assigns.status || "Inactive"}
      end

    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      {@label}
    </span>
    """
  end

  attr :label, :string, required: true
  attr :value, :float, required: true
  attr :icon, :string, required: true

  def rating_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
      <div class="flex items-center text-sm text-gray-600">
        <span class="mr-2 text-gray-400"><.row_icon name={@icon} /></span>
        {@label}
      </div>

      <div class="flex items-center">
        <div class="flex mr-2">
          <%= for star <- 1..5 do %>
            <.star filled={star <= round(@value)} />
          <% end %>
        </div>

        <span class="text-sm font-semibold text-gray-900">
          {:erlang.float_to_binary(@value, decimals: 1)}
        </span>
      </div>
    </div>
    """
  end

  attr :ratings, :map, required: true

  def score_summary(assigns) do
    overall =
      (assigns.ratings.delivery || 0) +
        (assigns.ratings.quality || 0) +
        (assigns.ratings.ripeness || 0) +
        (assigns.ratings.reliability || 0)

    assigns = assign(assigns, overall: overall)

    ~H"""
    <div class="mb-6 text-center p-4 bg-green-50 rounded-lg border border-green-100">
      <span class="block text-sm text-green-700 font-medium mb-1">Overall Score</span>

      <div class="flex items-center justify-center gap-2">
        <span class="text-3xl font-bold text-green-800">
          {:erlang.float_to_binary(@overall, decimals: 1)}
        </span>
        <span class="text-sm text-green-600">/ 20</span>
      </div>

      <span class="inline-block mt-2 px-2 py-0.5 bg-green-200 text-green-800 text-xs rounded-full font-medium">
        Preferred Supplier
      </span>
    </div>
    """
  end

  attr :filled, :boolean, default: false

  def star(assigns) do
    cls =
      if assigns.filled do
        "text-yellow-400 fill-yellow-400"
      else
        "text-gray-200"
      end

    assigns = assign(assigns, cls: cls)

    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={"w-3 h-3 #{@cls}"}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
    </svg>
    """
  end

  # Small inline icons for contact section
  attr :name, :string, required: true

  def mini_icon(assigns) do
    ~H"""
    <span class="inline-flex w-3 h-3 mr-2">
      <%= case @name do %>
        <% "phone" -> %>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-3 h-3"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.79 19.79 0 0 1 2.08 4.18 2 2 0 0 1 4.06 2h3a2 2 0 0 1 2 1.72c.12.81.3 1.6.54 2.36a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.72-1.06a2 2 0 0 1 2.11-.45c.76.24 1.55.42 2.36.54A2 2 0 0 1 22 16.92z" />
          </svg>
        <% "mail" -> %>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-3 h-3"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <rect x="2" y="4" width="20" height="16" rx="2"></rect>
            <path d="m22 7-10 7L2 7"></path>
          </svg>
        <% _ -> %>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-3 h-3"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 0 1 16 0Z"></path>
            <circle cx="12" cy="10" r="3"></circle>
          </svg>
      <% end %>
    </span>
    """
  end

  # Icons for rating rows
  attr :name, :string, required: true

  def row_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "truck" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M10 17h4V5H2v12h3"></path>
          <path d="M14 9h5l3 3v5h-2"></path>
          <circle cx="7.5" cy="17.5" r="2.5"></circle>
          <circle cx="17.5" cy="17.5" r="2.5"></circle>
        </svg>
      <% "shield" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"></path>
          <path d="m9 12 2 2 4-4"></path>
        </svg>
      <% "clock" -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <circle cx="12" cy="12" r="10"></circle>
          <path d="M12 6v6l4 2"></path>
        </svg>
      <% _ -> %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M3 17l6-6 4 4 8-8"></path>
          <path d="M14 7h7v7"></path>
        </svg>
    <% end %>
    """
  end
end
