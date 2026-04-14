defmodule AccessGuardianWeb.StatusHelpers do
  use Phoenix.Component

  attr :status, :atom, required: true
  attr :pending_manual, :boolean, default: false

  def status_badge(assigns) do
    {text, class} = badge_display(assigns.status, assigns.pending_manual)
    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"badge badge-sm #{@class}"}>
      {@text}
    </span>
    """
  end

  defp badge_display(:pending_approval, _), do: {"Pending", "badge-warning"}
  defp badge_display(:approved, _), do: {"Approved", "badge-info"}
  defp badge_display(:provisioning, true), do: {"Manual", "badge-warning badge-outline"}
  defp badge_display(:provisioning, _), do: {"Provisioning", "badge-info"}
  defp badge_display(:granted, _), do: {"Granted", "badge-success"}
  defp badge_display(:rejected, _), do: {"Rejected", "badge-error"}
  defp badge_display(:denied, _), do: {"Denied", "badge-error"}
  defp badge_display(_, _), do: {"Unknown", "badge-ghost"}

  def time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
