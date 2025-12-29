defmodule AvoflowWeb.SettingsLive do
  use AvoflowWeb, :live_view

  alias Phoenix.Component

  @impl true
  def mount(_params, _session, socket) do
    # Mock data from the provided React defaults (no DB calls)
    settings = %{
      "target_yield" => "66",
      "max_defects_allowed" => "5",
      "max_ph_level" => "4.6",
      "min_sanitizer_ppm" => "100",
      "max_cooling_time_min" => "90",
      "target_cooling_temp_c" => "4"
    }

    form = Component.to_form(settings, as: :settings)

    {:ok,
     socket
     |> assign(:q, "")
     |> assign(:unread_count, 3)
     |> assign(:user_label, "Documents E.Impact")
     |> assign(:settings, settings)
     |> assign(:form, form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="">
      <main class="">
        <div class="">
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Settings</h1>
            <p class="mt-1 text-gray-500">System configuration and parameters</p>
          </div>

          <div class="">
            <.form for={@form} phx-change="change" phx-submit="save" class="space-y-6">
              <.settings_card title="Production Parameters" class="mb-6">
                <div class="space-y-4">
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.settings_input
                      label="Target Yield (%)"
                      field={@form[:target_yield]}
                      inputmode="decimal"
                    />
                    <.settings_input
                      label="Max Defects Allowed (%)"
                      field={@form[:max_defects_allowed]}
                      inputmode="decimal"
                    />
                  </div>
                </div>
              </.settings_card>

              <.settings_card title="HACCP Limits" class="mb-6">
                <div class="space-y-4">
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <.settings_input
                      label="Max pH Level"
                      field={@form[:max_ph_level]}
                      inputmode="decimal"
                    />
                    <.settings_input
                      label="Min Sanitizer PPM"
                      field={@form[:min_sanitizer_ppm]}
                      inputmode="numeric"
                    />
                    <.settings_input
                      label="Max Cooling Time (min)"
                      field={@form[:max_cooling_time_min]}
                      inputmode="numeric"
                    />
                    <.settings_input
                      label="Target Cooling Temp (°C)"
                      field={@form[:target_cooling_temp_c]}
                      inputmode="decimal"
                    />
                  </div>
                </div>
              </.settings_card>

              <div class="flex justify-end">
                <.settings_button kind="primary" type="submit">Save Changes</.settings_button>
              </div>
            </.form>
          </div>
        </div>
      </main>
    </div>
    """
  end

  @impl true
  def handle_event("change", %{"settings" => params}, socket) do
    allowed = Map.keys(socket.assigns.settings)

    settings =
      socket.assigns.settings
      |> Map.merge(Map.take(params, allowed))

    form = Component.to_form(settings, as: :settings)

    {:noreply,
     socket
     |> assign(:settings, settings)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    # No-op save (mock). You can wire persistence later.
    {:noreply, put_flash(socket, :info, "Changes saved.")}
  end

  @impl true
  def handle_event("topbar_search", params, socket) do
    q =
      params["q"] ||
        params["query"] ||
        params["value"] ||
        socket.assigns.q

    {:noreply, assign(socket, :q, to_string(q))}
  end

  # --- Function components (HEEx) ---

  attr :title, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def settings_card(assigns) do
    ~H"""
    <section class={["rounded-xl border border-gray-200 bg-white shadow-sm", @class]}>
      <div class="border-b border-gray-100 px-5 py-4">
        <h2 class="text-sm font-semibold text-gray-900">{@title}</h2>
      </div>
      <div class="px-5 py-4">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :inputmode, :string, default: nil

  def settings_input(assigns) do
    ~H"""
    <div>
      <label for={@field.id} class="block text-sm font-medium text-gray-900">
        {@label}
      </label>
      <div class="mt-1">
        <input
          id={@field.id}
          name={@field.name}
          type={@type}
          value={@field.value}
          inputmode={@inputmode}
          class="block w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 shadow-sm outline-none placeholder:text-gray-400 focus:border-[#2E7D32] focus:ring-2 focus:ring-[#2E7D32] focus:ring-offset-0"
        />
      </div>
    </div>
    """
  end

  attr :kind, :string, default: "primary"
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def settings_button(assigns) do
    base_class = base_button_class()
    kind_class = kind_button_class(assigns.kind)

    assigns =
      assigns
      |> assign(:computed_class, [base_class, kind_class, assigns.class])

    ~H"""
    <button type={@type} class={@computed_class}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp base_button_class do
    "inline-flex items-center justify-center text-sm font-medium transition " <>
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32] focus-visible:ring-offset-2 " <>
      "disabled:opacity-50 disabled:pointer-events-none"
  end

  defp kind_button_class(kind) do
    case kind do
      "secondary" -> "bg-gray-100 text-gray-900 rounded-full h-9 px-4 text-sm"
      "ghost" -> "text-gray-600 hover:bg-gray-100 rounded-lg px-2 py-1 text-sm"
      _ -> "bg-[#2E7D32] text-white rounded-full h-9 px-4 text-sm"
    end
  end
end
