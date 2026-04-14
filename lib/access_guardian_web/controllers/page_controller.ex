defmodule AccessGuardianWeb.PageController do
  use AccessGuardianWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
