defmodule AvoflowWeb.CustomComponents do
  use Phoenix.Component

  attr :name, :string, required: true
  attr :class, :string, default: "w-5 h-5"

  def fg_svg_icon(assigns) do
    ~H"""
    <svg
      class={@class}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <%= case @name do %>
        <% "arrow-left" -> %>
          <path d="M19 12H5"></path>
          <path d="M12 19l-7-7 7-7"></path>
        <% "arrow-right" -> %>
          <path d="M5 12h14"></path>
          <path d="M12 5l7 7-7 7"></path>
        <% "check-circle" -> %>
          <path d="M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z"></path>
          <path d="m9 12 2 2 4-4"></path>
        <% "info" -> %>
          <path d="M12 2a10 10 0 1 1 0 20 10 10 0 0 1 0-20Z"></path>
          <path d="M12 16v-4"></path>
          <path d="M12 8h.01"></path>
        <% "alert-circle" -> %>
          <path d="M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20Z"></path>
          <path d="M12 8v4"></path>
          <path d="M12 16h.01"></path>
        <% "calendar" -> %>
          <path d="M8 2v4"></path>
          <path d="M16 2v4"></path>
          <path d="M3 10h18"></path>
          <path d="M5 6h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z"></path>
        <% "package" -> %>
          <path d="M16.5 9.4 7.5 4.2"></path>
          <path d="M21 16V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z">
          </path>
          <path d="M3.3 7.6 12 12l8.7-4.4"></path>
          <path d="M12 22V12"></path>
        <% "beaker" -> %>
          <path d="M6 2h12"></path>
          <path d="M10 2v6l-5.5 9.5A3 3 0 0 0 7.1 22h9.8a3 3 0 0 0 2.6-4.5L14 8V2"></path>
          <path d="M8 16h8"></path>
        <% "map-pin" -> %>
          <path d="M12 21s7-4.4 7-11a7 7 0 0 0-14 0c0 6.6 7 11 7 11Z"></path>
          <path d="M12 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z"></path>
        <% "printer" -> %>
          <path d="M6 9V2h12v7"></path>
          <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path>
          <path d="M6 14h12v8H6z"></path>
        <% _ -> %>
          <path d="M12 12h.01"></path>
      <% end %>
    </svg>
    """
  end
end
