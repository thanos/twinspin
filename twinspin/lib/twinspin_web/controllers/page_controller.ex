defmodule TwinspinWeb.PageController do
  use TwinspinWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
