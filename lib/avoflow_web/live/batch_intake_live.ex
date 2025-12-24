defmodule AvoflowWeb.BatchIntakeLive do
  use AvoflowWeb, :live_view

  alias AvoflowWeb.Components.TopBar
  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    form =
      %{
        "supplier_id" => "",
        "variety" => "",
        "date_received" => "",
        "quantity_kg" => "",
        "ripeness_score" => 1,
        "defects_percentage" => "",
        "notes" => ""
      }

    {:ok,
     assign(socket,
       page_title: "New Batch Intake",
       q: "",
       user_label: "User",
       unread_count: 0,
       is_submitting: false,
       form: form,
       supplier_options: [
         %{value: "1", label: "Avocorp"},
         %{value: "2", label: "GreenFarm"},
         %{value: "3", label: "AvoMasters"}
       ],
       variety_options: [
         %{value: "hass", label: "Hass"},
         %{value: "fuerte", label: "Fuerte"},
         %{value: "pinkerton", label: "Pinkerton"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="">
      <div class="">
        <!-- Match React's narrower content area -->
        <div class="mx-auto w-full">
          <!-- Back -->
          <.link
            navigate={~p"/batches"}
            class="inline-flex items-center text-sm text-gray-500 hover:text-gray-900 mb-4 transition-colors"
          >
            <!-- ArrowLeft icon -->
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
            Back to Batches
          </.link>
          
    <!-- Title -->
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-gray-900">New Batch Intake</h1>
            <p class="text-gray-500 mt-1">Record details for incoming avocado delivery</p>
          </div>
          
    <!-- Form -->
          <form phx-submit="save" phx-change="validate">
            <section class="rounded-2xl border border-gray-200 bg-white shadow-sm mb-6">
              <div class="p-5">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <!-- Supplier -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Supplier <span class="text-red-500">*</span>
                    </label>
                    <select
                      name="supplier_id"
                      required
                      class="w-full h-10 rounded-lg bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                             focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:border-[#2E7D32]/30 focus:bg-white transition"
                      value={@form["supplier_id"]}
                    >
                      <option value="" disabled selected={@form["supplier_id"] == ""}>
                        Select supplier
                      </option>
                      <%= for opt <- @supplier_options do %>
                        <option value={opt.value} selected={@form["supplier_id"] == opt.value}>
                          {opt.label}
                        </option>
                      <% end %>
                    </select>
                  </div>
                  
    <!-- Variety -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Variety <span class="text-red-500">*</span>
                    </label>
                    <select
                      name="variety"
                      required
                      class="w-full h-10 rounded-lg bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                             focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:border-[#2E7D32]/30 focus:bg-white transition"
                      value={@form["variety"]}
                    >
                      <option value="" disabled selected={@form["variety"] == ""}>
                        Select variety
                      </option>
                      <%= for opt <- @variety_options do %>
                        <option value={opt.value} selected={@form["variety"] == opt.value}>
                          {opt.label}
                        </option>
                      <% end %>
                    </select>
                  </div>
                  
    <!-- Date Received -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Date Received <span class="text-red-500">*</span>
                    </label>
                    <input
                      type="date"
                      name="date_received"
                      required
                      value={@form["date_received"]}
                      class="w-full h-10 rounded-lg bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                             focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:border-[#2E7D32]/30 focus:bg-white transition"
                    />
                  </div>
                  
    <!-- Quantity -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Quantity (kg) <span class="text-red-500">*</span>
                    </label>
                    <input
                      type="number"
                      name="quantity_kg"
                      inputmode="decimal"
                      step="0.1"
                      placeholder="0.00"
                      required
                      value={@form["quantity_kg"]}
                      class="w-full h-10 rounded-lg bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                             focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:border-[#2E7D32]/30 focus:bg-white transition"
                    />
                  </div>
                  
    <!-- Ripeness Score -->
                  <div class="col-span-1">
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Initial Ripeness Score (1-6)
                    </label>

                    <div class="flex space-x-2">
                      <%= for score <- 1..6 do %>
                        <button
                          type="button"
                          phx-click="set_ripeness"
                          phx-value-score={score}
                          class={[
                            "w-10 h-10 rounded-full flex items-center justify-center text-sm font-medium transition-all",
                            "focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#2E7D32]/60",
                            if(score == @form["ripeness_score"],
                              do: "bg-[#2E7D32] text-white",
                              else: "bg-gray-100 text-gray-600 hover:bg-gray-200"
                            )
                          ]}
                        >
                          {score}
                        </button>
                      <% end %>
                    </div>

                    <p class="text-xs text-gray-500 mt-2">1 = Hard Green, 6 = Overripe</p>
                    <input type="hidden" name="ripeness_score" value={@form["ripeness_score"]} />
                  </div>
                  
    <!-- Defects -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Defects (%)</label>
                    <input
                      type="number"
                      name="defects_percentage"
                      inputmode="decimal"
                      placeholder="0"
                      max="100"
                      value={@form["defects_percentage"]}
                      class="w-full h-10 rounded-lg bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                             focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:border-[#2E7D32]/30 focus:bg-white transition"
                    />
                  </div>
                  
    <!-- Notes -->
                  <div class="col-span-1 md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Notes</label>
                    <textarea
                      name="notes"
                      rows="4"
                      placeholder="Any observations about quality, transport conditions, etc."
                      class="w-full rounded-lg bg-gray-50 border border-gray-200 px-3 py-2 text-sm text-gray-900
                             focus:outline-none focus:ring-2 focus:ring-[#2E7D32]/20 focus:border-[#2E7D32]/30 focus:bg-white transition"
                    ><%= @form["notes"] %></textarea>
                  </div>
                </div>
              </div>
            </section>
            
    <!-- Actions -->
            <div class="flex justify-end gap-4">
              <.link
                navigate={~p"/batches"}
                class="inline-flex items-center justify-center h-9 px-4 rounded-full text-sm font-medium
                       bg-gray-100 text-gray-900 hover:bg-gray-200
                       focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
              >
                Cancel
              </.link>

              <button
                type="submit"
                class="inline-flex items-center justify-center h-9 px-4 rounded-full text-sm font-medium
                       bg-[#2E7D32] text-white hover:brightness-95
                       focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 disabled:opacity-60"
                disabled={@is_submitting}
              >
                <%= if @is_submitting do %>
                  Saving...
                <% else %>
                  Save Batch
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </main>
    """
  end

  # -------------------------
  # Events
  # -------------------------

  @impl true
  def handle_event("topbar_search", %{"q" => q}, socket), do: {:noreply, assign(socket, :q, q)}
  def handle_event("topbar_help", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_notifications", _params, socket), do: {:noreply, socket}
  def handle_event("topbar_user_menu", _params, socket), do: {:noreply, socket}

  def handle_event("set_ripeness", %{"score" => score}, socket) do
    score_int =
      case Integer.parse(to_string(score)) do
        {n, _} -> n
        _ -> 1
      end

    form = Map.put(socket.assigns.form, "ripeness_score", score_int)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("validate", params, socket) do
    # Keep it simple: just store the form fields in assigns.
    # params shape: %{"supplier_id" => "...", ...}
    form =
      socket.assigns.form
      |> Map.merge(params)
      |> Map.update("ripeness_score", 1, fn v ->
        case v do
          n when is_integer(n) ->
            n

          bin when is_binary(bin) ->
            case Integer.parse(bin) do
              {i, _} -> i
              _ -> 1
            end

          _ ->
            1
        end
      end)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", params, socket) do
    # Mock submit: mark submitting briefly and navigate back to /batches.
    # In real implementation, insert into DB then navigate.
    form = Map.merge(socket.assigns.form, params)

    socket =
      socket
      |> assign(:is_submitting, true)
      |> assign(:form, form)

    {:noreply, push_navigate(socket, to: ~p"/batches")}
  end
end
