defmodule AvoflowWeb.PageController do
  use AvoflowWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
