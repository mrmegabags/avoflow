
defmodule AvoflowWeb.ProductionLive do
  use AvoflowWeb, :live_view

  import Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    ready_batches = [
      %{
        id: "B-009",
        supplier_id: "1",
        supplier_name: "Avocorp",
        variety: "Hass",
        date_received: "2023-10-24",
        quantity_kg: 450.0,
        ripeness_score: 6,
        defects_percentage: 2.5,
        status: "Ready"
      },
      %{
        id: "B-012",
        supplier_id: "2",
        supplier_name: "GreenFarm",
        variety: "Hass",
        date_received: "2023-10-20",
        quantity_kg: 120.0,
        ripeness_score: 5,
        defects_percentage: 1.0,
        status: "Ready"
      }
    ]

    today = Date.utc_today() |> Date.to_iso8601()

    production = %{
      "run_date" => today,
      "planned_output" => "",
      "actual_output" => "",
      # loss accounting (kg)
      "spoiled_kg" => "",
      "to_oil_kg" => "",
      "unripe_kg" => "",
      # HACCP
      "sanitizer_ppm" => "",
      "ph_level" => "",
      "cooling_time" => "",
      "cooling_temp" => "",
      "corrective_actions" => ""
    }

    ingredient_specs = [
      %{key: "olive_oil", label: "Olive Oil", unit: "kg", ratio_per_kg_input: 0.020, guidance: "Before/after container weight"},
      %{key: "sodium_benzoate", label: "Sodium Benzoate", unit: "kg", ratio_per_kg_input: 0.0010, guidance: "Before/after container weight"},
      %{key: "ascorbic_acid", label: "Ascorbic Acid", unit: "kg", ratio_per_kg_input: 0.0015, guidance: "Before/after container weight"},
      %{key: "lemons", label: "Lemons (fruit)", unit: "kg", ratio_per_kg_input: 0.030, guidance: "Fruit weight only"},
      %{key: "salt", label: "Salt", unit: "kg", ratio_per_kg_input: 0.008, guidance: "Before/after container weight"},
      %{key: "sugar", label: "Sugar", unit: "kg", ratio_per_kg_input: 0.010, guidance: "Before/after container weight"}
    ]

    used =
      ingredient_specs
      |> Enum.map(&{&1.key, ""})
      |> Enum.into(%{})

    ingredient_inventory = %{
      "olive_oil" => 18.0,
      "sodium_benzoate" => 2.0,
      "ascorbic_acid" => 4.5,
      "lemons" => 35.0,
      "salt" => 25.0,
      "sugar" => 40.0
    }

    {:ok,
     socket
     |> assign(
       page_title: "Production",
       step: 1,
       ready_batches: ready_batches,
       selected_batches: [],
       production: production,
       ingredient_specs: ingredient_specs,
       used: used,
       ingredient_inventory: ingredient_inventory,
       # voice (progressive enhancement)
       voice_enabled: false,
       active_voice_field: "production[planned_output]",
       # derived
       total_input_kg: 0.0,
       loss_total_kg: 0.0,
       usable_input_kg: 0.0,
       loss_warning: nil,
       ingredient_plan: [],
       estimated_yield_pct: 65,
       actual_yield_pct: nil,
       sanitizer_status: :none,
       ph_status: :none,
       # output reconciliation
       any_actual_used: false,
       additives_total_kg: 0.0,
       expected_output_kg: 0.0,
       avocado_in_blend_kg: 0.0,
       output_variance_kg: nil,
       output_variance_pct: nil,
       reconciliation_note: nil
     )
     |> recompute()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-gray-900">New Production Run</h1>
      <p class="mt-1 text-sm text-gray-600">Process batches into finished product</p>
    </div>

    <div class="mx-auto w-full max-w-4xl">
      <div class="mb-8">
        <.breadcrumb
          items={[
            %{label: "Select Batches", active: @step == 1, completed: @step > 1},
            %{label: "Production Data", active: @step == 2, completed: @step > 2},
            %{label: "HACCP Checks", active: @step == 3, completed: false}
          ]}
        />
      </div>

      <%= if @step == 1 do %>
        <.card title="Step 1: Select Batches for Production">
          <div class="mb-6">
            <p class="text-sm text-gray-600 mb-4">
              Select the ready batches to include in this production run.
            </p>

            <div class="border border-gray-200 rounded-2xl overflow-hidden bg-white shadow-sm">
              <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Select</th>
                      <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Batch ID</th>
                      <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Supplier</th>
                      <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Qty Available</th>
                      <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Ripeness</th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-gray-100">
                    <%= for b <- @ready_batches do %>
                      <tr class="bg-white hover:bg-gray-50">
                        <td class="px-5 py-4">
                          <input
                            type="checkbox"
                            class="h-4 w-4 rounded border-gray-300 text-[#2E7D32]
                                   focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30"
                            checked={b.id in @selected_batches}
                            phx-click="toggle_batch"
                            phx-value-id={b.id}
                          />
                        </td>
                        <td class="px-5 py-4 text-gray-900 font-semibold"><%= b.id %></td>
                        <td class="px-5 py-4 text-gray-700"><%= b.supplier_name %></td>
                        <td class="px-5 py-4 text-gray-700 whitespace-nowrap"><%= fmt_qty(b.quantity_kg, "kg") %></td>
                        <td class="px-5 py-4 text-gray-700 whitespace-nowrap"><%= b.ripeness_score %>/6</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>

            <div class="mt-4 rounded-2xl bg-gray-50 p-5 border border-gray-200">
              <div class="flex items-center justify-between">
                <div class="text-sm text-gray-600">
                  Selected batches:
                  <span class="font-semibold text-gray-900"><%= length(@selected_batches) %></span>
                </div>
                <div class="text-sm text-gray-600">
                  Total input:
                  <span class="font-semibold text-gray-900"><%= fmt_qty(@total_input_kg, "kg") %></span>
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end">
            <.btn variant="primary" phx-click="next_step" disabled={length(@selected_batches) == 0}>
              Next Step <span class="ml-2">→</span>
            </.btn>
          </div>
        </.card>
      <% end %>

      <%= if @step == 2 do %>
        <.card title="Step 2: Production Data">
          <!-- Summary first (operator mental model): Input → Losses → Additives → Measured Output -->
          <div class="mb-8 grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
              <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Total raw input</p>
              <p class="mt-2 text-xl font-semibold text-gray-900"><%= fmt_qty(@total_input_kg, "kg") %></p>
              <p class="mt-2 text-xs text-gray-500">From selected batches</p>
            </div>

            <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
              <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Loss total</p>
              <p class="mt-2 text-xl font-semibold text-gray-900"><%= fmt_qty(@loss_total_kg, "kg") %></p>
              <p class="mt-2 text-xs text-gray-500">Spoiled + to oil + unripe</p>
            </div>

            <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
              <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Usable avocado input</p>
              <p class="mt-2 text-xl font-semibold text-gray-900"><%= fmt_qty(@usable_input_kg, "kg") %></p>
              <p class="mt-2 text-xs text-gray-500">Base for additives + yield</p>
            </div>
          </div>

          <form phx-change="production_change" class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <.field label="Run Date" type="date" name="production[run_date]" value={@production["run_date"]} />

            <.field label="Operator" type="text" name="operator" value="John Doe (You)" disabled class="bg-gray-50" />

            <.field
              label="Planned Output (kg)"
              type="number"
              step="0.1"
              name="production[planned_output]"
              placeholder="0.0"
              value={@production["planned_output"]}
              data_voice_field="production[planned_output]"
              helper_text="Planning only (optional)"
            />

            <.field
              label="Total Raw Input (kg)"
              type="number"
              name="total_input"
              value={fmt_number(@total_input_kg)}
              disabled
              helper_text="Sum of selected batches"
              class="bg-gray-50"
            />

            <!-- Loss accounting -->
            <div class="md:col-span-2 rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Input Adjustments</h3>
                <p class="text-xs text-gray-500 mt-1">
                  Record any raw input that will NOT become purée. Usable input drives additive estimates.
                </p>
              </div>

              <div class="p-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Spoiled (kg)</label>
                  <input
                    type="number"
                    step="0.1"
                    name="production[spoiled_kg]"
                    value={@production["spoiled_kg"]}
                    placeholder="0.0"
                    data-voice-field="production[spoiled_kg]"
                    class="w-full h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                  <p class="text-xs text-gray-500 mt-2">Discard / waste</p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">To Oil (kg)</label>
                  <input
                    type="number"
                    step="0.1"
                    name="production[to_oil_kg]"
                    value={@production["to_oil_kg"]}
                    placeholder="0.0"
                    data-voice-field="production[to_oil_kg]"
                    class="w-full h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                  <p class="text-xs text-gray-500 mt-2">Divert to oil production</p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Unripe (kg)</label>
                  <input
                    type="number"
                    step="0.1"
                    name="production[unripe_kg]"
                    value={@production["unripe_kg"]}
                    placeholder="0.0"
                    data-voice-field="production[unripe_kg]"
                    class="w-full h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                  <p class="text-xs text-gray-500 mt-2">Hold back / return to ripening</p>
                </div>

                <div class="sm:col-span-3 mt-2 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 rounded-2xl bg-gray-50 p-5 border border-gray-200">
                  <div class="text-sm text-gray-600">
                    Loss total:
                    <span class="font-semibold text-gray-900"><%= fmt_qty(@loss_total_kg, "kg") %></span>
                  </div>
                  <div class="text-sm text-gray-600">
                    Usable input:
                    <span class="font-semibold text-gray-900"><%= fmt_qty(@usable_input_kg, "kg") %></span>
                  </div>
                  <%= if @loss_warning do %>
                    <div class="text-sm text-red-700 font-medium"><%= @loss_warning %></div>
                  <% end %>
                </div>
              </div>
            </div>
          </form>

          <!-- Ingredients next (so reconciliation isn't a black box) -->
          <form phx-change="ingredients_change" class="mb-8">
            <div class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Ingredients (Estimate + Actual Used)</h3>
                <p class="text-xs text-gray-500 mt-1">
                  Estimated needs are based on usable input (<%= fmt_qty(@usable_input_kg, "kg") %>).
                  If any actual used values are entered, remaining blanks will still use estimates.
                </p>
              </div>

              <div class="p-5">
                <div class="overflow-x-auto">
                  <table class="min-w-full text-sm">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Ingredient</th>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Available</th>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Estimated Needed</th>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Remaining (Est)</th>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Actual Used</th>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Status</th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-gray-100">
                      <%= for ing <- @ingredient_plan do %>
                        <tr class="bg-white hover:bg-gray-50">
                          <td class="px-5 py-4 text-gray-900 font-semibold whitespace-nowrap">
                            <%= ing.label %>
                            <div class="text-xs text-gray-500 mt-1"><%= ing.guidance %></div>
                          </td>

                          <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                            <%= fmt_qty(ing.available_qty, ing.unit) %>
                          </td>

                          <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                            <%= fmt_qty(ing.estimated_qty, ing.unit) %>
                            <div class="text-xs text-gray-500 mt-1"><%= fmt_ratio(ing.ratio_per_kg_input) %> / kg</div>
                          </td>

                          <td class="px-5 py-4 text-gray-700 whitespace-nowrap">
                            <%= fmt_qty(ing.remaining_est, ing.unit) %>
                          </td>

                          <td class="px-5 py-4 whitespace-nowrap">
                            <input
                              type="number"
                              step="0.001"
                              name={"used[#{ing.key}]"}
                              value={@used[ing.key] || ""}
                              placeholder={fmt_number(ing.estimated_qty)}
                              data-voice-field={"used[#{ing.key}]"}
                              class="w-40 h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                                     focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                            />
                            <span class="ml-2 text-xs text-gray-500"><%= ing.unit %></span>
                          </td>

                          <td class="px-5 py-4 whitespace-nowrap">
                            <.status_badge status={ing.stock_status} />
                          </td>
                        </tr>
                      <% end %>

                      <%= if Enum.empty?(@ingredient_plan) do %>
                        <tr>
                          <td colspan="6" class="px-5 py-8 text-center text-sm text-gray-500">
                            Select at least one batch to compute ingredient estimates.
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>

                <div class="mt-4 rounded-2xl bg-gray-50 p-5 border border-gray-200">
                  <p class="text-sm text-gray-600">
                    Additives total:
                    <span class="font-semibold text-gray-900"><%= fmt_qty(@additives_total_kg, "kg") %></span>
                    <span class="text-xs text-gray-500 ml-2"><%= @reconciliation_note || "" %></span>
                  </p>
                </div>
              </div>
            </div>
          </form>

          <!-- Actual measurement last -->
          <form phx-change="production_change" class="mb-8">
            <div class="rounded-2xl border border-gray-200 bg-white shadow-sm">
              <div class="px-5 pt-5">
                <h3 class="text-sm font-semibold text-gray-900">Output Measurement</h3>
                <p class="text-xs text-gray-500 mt-1">Enter after weighing the total finished product.</p>
              </div>

              <div class="p-5 grid grid-cols-1 md:grid-cols-2 gap-6">
                <.field
                  label="Actual Measured Output (kg)"
                  type="number"
                  step="0.1"
                  name="production[actual_output]"
                  placeholder="Enter after weighing"
                  value={@production["actual_output"]}
                  data_voice_field="production[actual_output]"
                  helper_text="Used to compute variance and estimated avocado purée in final"
                />
              </div>
            </div>
          </form>

          <!-- Reconciliation last; stable and explicit -->
          <div class="mb-8 rounded-2xl border border-gray-200 bg-white shadow-sm">
            <div class="px-5 pt-5">
              <h3 class="text-sm font-semibold text-gray-900">Reconciliation</h3>
              <p class="text-xs text-gray-500 mt-1">
                Expected blend output = usable input + additives total. Additives use actual used if entered, otherwise estimated.
              </p>
            </div>

            <div class="p-5 grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div class="rounded-2xl bg-gray-50 border border-gray-200 p-5">
                <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Expected blend output</p>
                <p class="mt-2 text-xl font-semibold text-gray-900"><%= fmt_qty(@expected_output_kg, "kg") %></p>
                <p class="mt-2 text-xs text-gray-500">Usable input + additives</p>
              </div>

              <div class="rounded-2xl bg-gray-50 border border-gray-200 p-5">
                <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Estimated avocado purée in final</p>
                <p class="mt-2 text-xl font-semibold text-gray-900"><%= fmt_qty(@avocado_in_blend_kg, "kg") %></p>
                <p class="mt-2 text-xs text-gray-500">
                  If actual output entered: actual output − additives.
                </p>
              </div>

              <div class="rounded-2xl bg-gray-50 border border-gray-200 p-5">
                <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Variance vs expected</p>

                <%= if is_number(@output_variance_kg) and is_number(@output_variance_pct) do %>
                  <p class="mt-2 text-xl font-semibold text-gray-900">
                    <%= fmt_signed_qty(@output_variance_kg, "kg") %>
                    <span class="text-sm text-gray-600 font-medium">(<%= fmt_signed_pct(@output_variance_pct) %>)</span>
                  </p>
                  <p class="mt-2 text-xs text-gray-500">Actual output − expected blend output</p>
                <% else %>
                  <p class="mt-2 text-sm text-gray-600">Enter actual measured output to calculate variance.</p>
                <% end %>
              </div>

              <div class="rounded-2xl bg-gray-50 border border-gray-200 p-5">
                <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Yield</p>
                <p class="mt-2 text-sm text-gray-700">
                  Planned: <span class="font-semibold text-gray-900"><%= @estimated_yield_pct %>%</span>
                </p>
                <p class="mt-1 text-sm text-gray-700">
                  Actual: <span class="font-semibold text-gray-900"><%= if @actual_yield_pct, do: "#{@actual_yield_pct}%", else: "—" %></span>
                </p>
                <p class="mt-2 text-xs text-gray-500">
                  Yield is output ÷ usable input (may exceed 100% due to additives).
                </p>
              </div>
            </div>
          </div>

          <div class="flex justify-between">
            <.btn variant="secondary" phx-click="prev_step">
              <span class="mr-2">←</span> Back
            </.btn>
            <.btn variant="primary" phx-click="next_step">
              Next Step <span class="ml-2">→</span>
            </.btn>
          </div>
        </.card>
      <% end %>

      <%= if @step == 3 do %>
        <.card title="Step 3: HACCP Critical Control Points">
          <div class="space-y-6 mb-8">
            <div class="p-5 border border-gray-200 rounded-2xl bg-white shadow-sm">
              <h4 class="text-sm font-semibold text-gray-900 mb-4">CCP #1: Sanitizer Concentration</h4>

              <div class="flex flex-col sm:flex-row sm:items-end gap-4">
                <form phx-change="production_change">
                  <label class="block text-sm font-medium text-gray-700 mb-2">PPM Value</label>
                  <input
                    type="number"
                    name="production[sanitizer_ppm]"
                    placeholder="e.g. 120"
                    value={@production["sanitizer_ppm"]}
                    data-voice-field="production[sanitizer_ppm]"
                    class="w-40 h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                </form>

                <div class="pb-1">
                  <%= if @sanitizer_status == :pass do %>
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20">
                      PASS
                    </span>
                  <% end %>

                  <%= if @sanitizer_status == :fail do %>
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/20">
                      FAIL
                    </span>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="p-5 border border-gray-200 rounded-2xl bg-white shadow-sm">
              <h4 class="text-sm font-semibold text-gray-900 mb-4">CCP #2: Product pH</h4>

              <div class="flex flex-col sm:flex-row sm:items-end gap-4">
                <form phx-change="production_change">
                  <label class="block text-sm font-medium text-gray-700 mb-2">pH Level</label>
                  <input
                    type="number"
                    step="0.01"
                    name="production[ph_level]"
                    placeholder="e.g. 4.2"
                    value={@production["ph_level"]}
                    data-voice-field="production[ph_level]"
                    class="w-40 h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                </form>

                <div class="pb-1">
                  <%= if @ph_status == :pass do %>
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20">
                      PASS
                    </span>
                  <% end %>

                  <%= if @ph_status == :fail do %>
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/20">
                      FAIL
                    </span>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="p-5 border border-gray-200 rounded-2xl bg-white shadow-sm">
              <h4 class="text-sm font-semibold text-gray-900 mb-4">CCP #3: Cooling</h4>

              <form phx-change="production_change" class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Time to ≤5°C (min)</label>
                  <input
                    type="number"
                    name="production[cooling_time]"
                    placeholder="e.g. 65"
                    value={@production["cooling_time"]}
                    data-voice-field="production[cooling_time]"
                    class="w-full h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Final Temp (°C)</label>
                  <input
                    type="number"
                    step="0.1"
                    name="production[cooling_temp]"
                    placeholder="e.g. 4"
                    value={@production["cooling_temp"]}
                    data-voice-field="production[cooling_temp]"
                    class="w-full h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900
                           focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
                  />
                </div>
              </form>
            </div>

            <form phx-change="production_change">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Corrective Actions (if any FAIL)
              </label>
              <textarea
                name="production[corrective_actions]"
                placeholder="Describe actions taken..."
                class="w-full min-h-[96px] rounded-2xl bg-gray-50 border border-gray-200 px-4 py-3 text-sm text-gray-900
                       focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white"
              ><%= @production["corrective_actions"] || "" %></textarea>
            </form>
          </div>

          <div class="flex justify-between">
            <.btn variant="secondary" phx-click="prev_step">
              <span class="mr-2">←</span> Back
            </.btn>

            <.btn variant="primary" phx-click="complete_run">
              Complete Production Run
            </.btn>
          </div>
        </.card>
      <% end %>
    </div>
    """
  end

  # -------------------------
  # Events
  # -------------------------

  @impl true
  def handle_event("toggle_batch", %{"id" => id}, socket) do
    selected =
      if id in socket.assigns.selected_batches do
        Enum.reject(socket.assigns.selected_batches, &(&1 == id))
      else
        [id | socket.assigns.selected_batches]
      end

    {:noreply, socket |> assign(:selected_batches, selected) |> recompute()}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    step = socket.assigns.step

    cond do
      step == 1 and length(socket.assigns.selected_batches) == 0 ->
        {:noreply, socket}

      step < 3 ->
        {:noreply, socket |> assign(:step, step + 1) |> recompute()}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, max(socket.assigns.step - 1, 1))}
  end

  @impl true
  def handle_event("production_change", %{"production" => params}, socket) do
    {:noreply, socket |> assign(:production, Map.merge(socket.assigns.production, params)) |> recompute()}
  end

  @impl true
  def handle_event("ingredients_change", %{"used" => used_params}, socket) do
    {:noreply, socket |> assign(:used, Map.merge(socket.assigns.used, used_params)) |> recompute()}
  end

  @impl true
  def handle_event("complete_run", _params, socket) do
    {:noreply, put_flash(socket, :info, "Production run marked complete (mock).")}
  end

  # Voice controls (works even if hook is not installed)
  @impl true
  def handle_event("voice_toggle", _params, socket) do
    {:noreply, assign(socket, :voice_enabled, not socket.assigns.voice_enabled)}
  end

  @impl true
  def handle_event("voice_set_field", %{"field" => field}, socket) do
    {:noreply, assign(socket, :active_voice_field, field)}
  end

  @impl true
  def handle_event("voice_clear", _params, socket) do
    {:noreply, socket |> clear_active_voice_field() |> recompute()}
  end

  @impl true
  def handle_event("voice_set", %{"field" => field, "value" => value}, socket) do
    socket =
      cond do
        String.starts_with?(field, "production[") ->
          key = field |> String.trim_leading("production[") |> String.trim_trailing("]")
          assign(socket, :production, Map.put(socket.assigns.production, key, value))

        String.starts_with?(field, "used[") ->
          key = field |> String.trim_leading("used[") |> String.trim_trailing("]")
          assign(socket, :used, Map.put(socket.assigns.used, key, value))

        true ->
          socket
      end

    {:noreply, recompute(socket)}
  end

  # -------------------------
  # Function components
  # -------------------------

  attr :title, :string, required: true
  slot :inner_block, required: true
  def card(assigns) do
    ~H"""
    <section class="rounded-2xl border border-gray-200 bg-white shadow-sm">
      <div class="px-5 pt-5">
        <h3 class="text-sm font-semibold text-gray-900"><%= @title %></h3>
      </div>
      <div class="p-5">
        <%= render_slot(@inner_block) %>
      </div>
    </section>
    """
  end

  attr :variant, :string, default: "primary"
  attr :disabled, :boolean, default: false
  attr :type, :string, default: "button"
  attr :rest, :global
  slot :inner_block, required: true
  def btn(assigns) do
    base =
      "inline-flex items-center justify-center font-medium transition-colors " <>
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 " <>
        "disabled:opacity-50 disabled:cursor-not-allowed"

    {variant_cls, size_cls} =
      case assigns.variant do
        "secondary" -> {"bg-gray-100 text-gray-900 hover:bg-gray-200", "rounded-full h-9 px-4 text-sm"}
        "ghost" -> {"text-gray-600 hover:bg-gray-100", "rounded-lg px-2 py-1 text-sm"}
        _ -> {"bg-[#2E7D32] text-white hover:brightness-95", "rounded-full h-9 px-4 text-sm"}
      end

    assigns = assign(assigns, :class, Enum.join([base, variant_cls, size_cls], " "))

    ~H"""
    <button type={@type} class={@class} disabled={@disabled} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :items, :list, required: true
  def breadcrumb(assigns) do
    ~H"""
    <ol class="flex items-center gap-3 text-sm">
      <%= for {item, idx} <- Enum.with_index(@items) do %>
        <li class="flex items-center gap-3">
          <div class="flex items-center gap-2">
            <span class={[
              "inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold",
              item.completed && "bg-[#2E7D32] text-white",
              item.active && !item.completed && "bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20",
              !item.active && !item.completed && "bg-gray-100 text-gray-600"
            ]}>
              <%= idx + 1 %>
            </span>

            <span class={[
              "font-medium",
              item.active && "text-gray-900",
              !item.active && "text-gray-500"
            ]}>
              <%= item.label %>
            </span>
          </div>

          <%= if idx < length(@items) - 1 do %>
            <span class="text-gray-300">—</span>
          <% end %>
        </li>
      <% end %>
    </ol>
    """
  end

  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :step, :string, default: nil
  attr :helper_text, :string, default: nil
  attr :class, :string, default: ""
  attr :data_voice_field, :string, default: nil
  def field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2"><%= @label %></label>
      <input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        step={@step}
        disabled={@disabled}
        data-voice-field={@data_voice_field}
        class={[
          "w-full h-10 rounded-full bg-gray-50 border border-gray-200 px-3 text-sm text-gray-900",
          "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus:ring-[#2E7D32]/20 focus:bg-white",
          @class
        ]}
      />
      <%= if @helper_text do %>
        <p class="text-xs text-gray-500 mt-2"><%= @helper_text %></p>
      <% end %>
    </div>
    """
  end

  attr :status, :atom, required: true
  def status_badge(assigns) do
    {cls, label} =
      case assigns.status do
        :low -> {"bg-yellow-50 text-yellow-700 ring-yellow-600/20", "Low"}
        :out -> {"bg-red-50 text-red-700 ring-red-600/20", "Insufficient"}
        _ -> {"bg-green-50 text-green-700 ring-green-600/20", "OK"}
      end

    assigns = assign(assigns, cls: cls, label: label)

    ~H"""
    <span class={"inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset #{@cls}"}>
      <%= @label %>
    </span>
    """
  end

  # -------------------------
  # Derived data
  # -------------------------

  defp recompute(socket) do
    total_input_kg =
      socket.assigns.ready_batches
      |> Enum.filter(fn b -> b.id in socket.assigns.selected_batches end)
      |> Enum.reduce(0.0, fn b, acc -> acc + safe_num(b.quantity_kg) end)

    spoiled = parse_f(socket.assigns.production["spoiled_kg"]) || 0.0
    to_oil = parse_f(socket.assigns.production["to_oil_kg"]) || 0.0
    unripe = parse_f(socket.assigns.production["unripe_kg"]) || 0.0

    loss_total = max(spoiled, 0.0) + max(to_oil, 0.0) + max(unripe, 0.0)

    {usable_input, loss_warning} =
      cond do
        total_input_kg <= 0 ->
          {0.0, nil}

        loss_total <= total_input_kg ->
          {total_input_kg - loss_total, nil}

        true ->
          {0.0, "Losses exceed total input. Please correct the values."}
      end

    ingredient_plan =
      socket.assigns.ingredient_specs
      |> Enum.map(fn ing ->
        est = usable_input * safe_num(ing.ratio_per_kg_input)
        available = socket.assigns.ingredient_inventory[to_string(ing.key)] || 0.0
        remaining_est = available - est

        stock_status =
          cond do
            est <= 0 -> :ok
            available <= 0 -> :out
            remaining_est < 0 -> :out
            remaining_est / max(available, 1.0) < 0.15 -> :low
            true -> :ok
          end

        ing
        |> Map.put(:estimated_qty, est)
        |> Map.put(:available_qty, available)
        |> Map.put(:remaining_est, remaining_est)
        |> Map.put(:stock_status, stock_status)
      end)

    planned_output = parse_f(socket.assigns.production["planned_output"])
    actual_output = parse_f(socket.assigns.production["actual_output"])

    estimated_yield_pct =
      cond do
        usable_input > 0 and is_number(planned_output) and planned_output >= 0 ->
          (planned_output / usable_input * 100.0) |> min(999.0) |> max(0.0) |> round()

        true ->
          65
      end

    actual_yield_pct =
      cond do
        usable_input > 0 and is_number(actual_output) and actual_output >= 0 ->
          (actual_output / usable_input * 100.0) |> min(999.0) |> max(0.0) |> round()

        true ->
          nil
      end

    any_actual_used =
      ingredient_plan
      |> Enum.any?(fn ing ->
        used_val = parse_f(socket.assigns.used[ing.key])
        is_number(used_val)
      end)

    # Additives: use actual used if entered, else fall back to estimated.
    # If any actual used is present, show a note that blanks still use estimates.
    additives_total =
      ingredient_plan
      |> Enum.reduce(0.0, fn ing, acc ->
        used_val = parse_f(socket.assigns.used[ing.key])

        val =
          if is_number(used_val) do
            max(used_val, 0.0)
          else
            max(ing.estimated_qty, 0.0)
          end

        acc + val
      end)

    reconciliation_note =
      cond do
        any_actual_used -> "Some blanks may still be using estimates."
        true -> "Using estimates (enter actual used to override)."
      end

    expected_output = max(usable_input, 0.0) + max(additives_total, 0.0)

    {avocado_in_blend, variance_kg, variance_pct} =
      cond do
        is_number(actual_output) and actual_output >= 0 and expected_output > 0 ->
          avocado_est = max(actual_output - additives_total, 0.0)
          var_kg = actual_output - expected_output
          var_pct = var_kg / expected_output * 100.0
          {avocado_est, var_kg, Float.round(var_pct, 1)}

        true ->
          {max(usable_input, 0.0), nil, nil}
      end

    sanitizer_status = sanitizer_status(socket.assigns.production["sanitizer_ppm"])
    ph_status = ph_status(socket.assigns.production["ph_level"])

    assign(socket,
      total_input_kg: total_input_kg,
      loss_total_kg: loss_total,
      usable_input_kg: usable_input,
      loss_warning: loss_warning,
      ingredient_plan: ingredient_plan,
      estimated_yield_pct: estimated_yield_pct,
      actual_yield_pct: actual_yield_pct,
      sanitizer_status: sanitizer_status,
      ph_status: ph_status,
      any_actual_used: any_actual_used,
      additives_total_kg: Float.round(additives_total, 2),
      expected_output_kg: Float.round(expected_output, 2),
      avocado_in_blend_kg: Float.round(avocado_in_blend, 2),
      output_variance_kg: if(is_number(variance_kg), do: Float.round(variance_kg, 2), else: nil),
      output_variance_pct: variance_pct,
      reconciliation_note: reconciliation_note
    )
  end

  defp safe_num(v) when is_number(v), do: v * 1.0
  defp safe_num(_), do: 0.0

  defp parse_f(nil), do: nil
  defp parse_f(""), do: nil
  defp parse_f(v) when is_number(v), do: v * 1.0

  defp parse_f(v) when is_binary(v) do
    v = String.trim(v)

    case Float.parse(v) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp sanitizer_status(v) do
    ppm = parse_f(v)

    cond do
      is_nil(ppm) -> :none
      ppm >= 100 -> :pass
      true -> :fail
    end
  end

  defp ph_status(v) do
    ph = parse_f(v)

    cond do
      is_nil(ph) -> :none
      ph > 0 and ph <= 4.6 -> :pass
      true -> :fail
    end
  end

  defp fmt_qty(qty, "kg") when is_number(qty) do
    dec = if qty < 10, do: 2, else: 1
    :erlang.float_to_binary(qty * 1.0, decimals: dec) <> " kg"
  end

  defp fmt_qty(qty, unit) when is_number(qty) and is_binary(unit) do
    Integer.to_string(trunc(qty)) <> " " <> unit
  end

  defp fmt_qty(_qty, unit) when is_binary(unit), do: "0 " <> unit
  defp fmt_qty(_qty, _unit), do: "0"

  defp fmt_signed_qty(qty, unit) when is_number(qty) and is_binary(unit) do
    sign = if qty > 0, do: "+", else: ""
    sign <> fmt_qty(qty, unit)
  end

  defp fmt_signed_pct(pct) when is_number(pct) do
    sign = if pct > 0, do: "+", else: ""
    sign <> :erlang.float_to_binary(pct * 1.0, decimals: 1) <> "%"
  end

  defp fmt_number(n) when is_number(n), do: :erlang.float_to_binary(n * 1.0, decimals: 1)
  defp fmt_number(_), do: "0.0"

  defp fmt_ratio(r) when is_number(r), do: :erlang.float_to_binary(r * 1.0, decimals: 4)
  defp fmt_ratio(_), do: "0.0000"

  defp clear_active_voice_field(socket) do
    field = socket.assigns.active_voice_field || ""

    cond do
      String.starts_with?(field, "production[") ->
        key = field |> String.trim_leading("production[") |> String.trim_trailing("]")
        assign(socket, :production, Map.put(socket.assigns.production, key, ""))

      String.starts_with?(field, "used[") ->
        key = field |> String.trim_leading("used[") |> String.trim_trailing("]")
        assign(socket, :used, Map.put(socket.assigns.used, key, ""))

      true ->
        socket
    end
  end
end



