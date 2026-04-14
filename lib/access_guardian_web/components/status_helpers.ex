defmodule AccessGuardianWeb.StatusHelpers do
  use Phoenix.Component

  attr :status, :atom, required: true
  attr :pending_manual, :boolean, default: false

  def status_badge(assigns) do
    {text, class} = badge_display(assigns.status, assigns.pending_manual)
    assigns = assign(assigns, text: text, class: class)

    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{@class}"}>
      {@text}
    </span>
    """
  end

  defp badge_display(:pending_approval, _), do: {"Pending", "bg-yellow-100 text-yellow-800"}
  defp badge_display(:approved, _), do: {"Approved", "bg-blue-100 text-blue-800"}
  defp badge_display(:provisioning, true), do: {"Manual", "bg-orange-100 text-orange-800"}
  defp badge_display(:provisioning, _), do: {"Provisioning", "bg-blue-100 text-blue-800"}
  defp badge_display(:granted, _), do: {"Granted", "bg-green-100 text-green-800"}
  defp badge_display(:rejected, _), do: {"Rejected", "bg-red-100 text-red-800"}
  defp badge_display(:denied, _), do: {"Denied", "bg-red-100 text-red-800"}
  defp badge_display(_, _), do: {"Unknown", "bg-gray-100 text-gray-800"}

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
