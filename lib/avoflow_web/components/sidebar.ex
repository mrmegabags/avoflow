defmodule AvoflowWeb.Components.Sidebar do
  use AvoflowWeb, :html

  attr :navigation, :list, required: true
  attr :current_path, :string, required: true
  attr :user, :map, required: true

  def sidebar(assigns) do
    ~H"""
    <aside class="hidden lg:flex w-60 bg-[#1A1C1E] text-white flex-col h-screen fixed left-0 top-0 z-30 overflow-y-auto">
      <div class="h-16 flex items-center px-6 border-b border-gray-800 flex-shrink-0">
        <div class="flex items-center space-x-2">
          <div class="w-8 h-8 bg-[#2E7D32] rounded-lg flex items-center justify-center">
            <span class="font-bold text-white">A</span>
          </div>
          <span class="font-bold text-lg tracking-tight">AvoFlow</span>
        </div>
      </div>

      <nav class="flex-1 py-6 px-3 space-y-1">
        <%= for item <- @navigation do %>
          <.nav_item item={item} current_path={@current_path} />
        <% end %>
      </nav>

      <div class="p-4 border-t border-gray-800 flex-shrink-0">
        <div class="flex items-center space-x-3">
          <div class="w-8 h-8 rounded-full bg-gray-700 flex items-center justify-center text-xs font-semibold">
            {Map.get(@user, :initials, "")}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-white truncate">{Map.get(@user, :name, "")}</p>
            <p class="text-xs text-gray-500 truncate">{Map.get(@user, :role, "")}</p>
          </div>
        </div>
      </div>
    </aside>
    """
  end

  attr :item, :map, required: true
  attr :current_path, :string, required: true

  def nav_item(assigns) do
    active = nav_active?(assigns.current_path, assigns.item.href)

    assigns =
      assigns
      |> assign(:active, active)
      |> assign(
        :link_class,
        [
          "flex items-center px-3 py-2.5 rounded-md text-sm font-medium transition-all duration-200",
          "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2E7D32]/30 focus-visible:ring-offset-2 focus-visible:ring-offset-[#1A1C1E]",
          if(active,
            do: "bg-[#2E7D32] text-white shadow-md translate-x-1",
            else: "text-gray-400 hover:text-white hover:bg-white/5"
          )
        ]
        |> Enum.join(" ")
      )

    ~H"""
    <.link navigate={nav_path(@item.href)} class={@link_class}>
      <.nav_icon />
      {@item.name}
    </.link>
    """
  end

  defp nav_icon(assigns) do
    ~H"""
    <svg class="w-5 h-5 mr-3 flex-shrink-0" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
      <path d="M10 3a7 7 0 100 14 7 7 0 000-14zm0 4a3 3 0 110 6 3 3 0 010-6z" />
    </svg>
    """
  end

  defp nav_active?(current_path, href) when is_binary(current_path) and is_binary(href) do
    cond do
      href == "/" -> current_path == "/"
      true -> String.starts_with?(current_path <> "/", href <> "/")
    end
  end

  defp nav_active?(_, _), do: false

  # Keep ~p for known routes (as you requested).
  defp nav_path("/"), do: ~p"/"
  defp nav_path("/suppliers"), do: ~p"/suppliers"
  defp nav_path("/batches"), do: ~p"/batches"
  defp nav_path("/inventory"), do: ~p"/inventory"
  defp nav_path("/production"), do: ~p"/production"
  defp nav_path("/finished-goods/pack"), do: ~p"/finished-goods/pack"
  defp nav_path("/finished-goods/ledger"), do: ~p"/finished-goods/ledger"
  defp nav_path("/finished-goods/fulfill"), do: ~p"/finished-goods/fulfill"
  defp nav_path("/finished-goods/adjustments"), do: ~p"/finished-goods/adjustments"
  defp nav_path("/finished-goods/cycle-counts"), do: ~p"/finished-goods/cycle-counts"
  defp nav_path("/finished-goods/holds"), do: ~p"/finished-goods/holds"
  defp nav_path("/finished-goods/integrations"), do: ~p"/finished-goods/integrations"
  defp nav_path("/haccp"), do: ~p"/haccp"
  defp nav_path("/settings"), do: ~p"/settings"
  defp nav_path(other) when is_binary(other), do: other
end
