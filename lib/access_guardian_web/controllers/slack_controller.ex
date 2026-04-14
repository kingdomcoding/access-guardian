defmodule AccessGuardianWeb.SlackController do
  use AccessGuardianWeb, :controller

  def commands(conn, _params) do
    send_resp(conn, 200, "")
  end

  def interactions(conn, _params) do
    send_resp(conn, 200, "")
  end

  def events(conn, _params) do
    send_resp(conn, 200, "")
  end
end
