defmodule AccessGuardianWeb.IntegrationSetupLive do
  use AccessGuardianWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, apps} = Ash.read(AccessGuardian.Catalog.Application)
    gitlab_app = Enum.find(apps, &(&1.config["gitlab_group_path"]))

    current_session =
      if gitlab_app do
        case Ash.read(AccessGuardian.Catalog.IntegrationSession) do
          {:ok, sessions} ->
            Enum.find(sessions, &(&1.platform == :gitlab and &1.status == :active))

          _ ->
            nil
        end
      end

    group_path = gitlab_app && gitlab_app.config["gitlab_group_path"]

    {:ok,
     assign(socket,
       page_title: "Integration Setup",
       gitlab_app: gitlab_app,
       current_session: current_session,
       group_path: group_path || "",
       status: nil,
       submitting: false
     )}
  end

  @impl true
  def handle_event("submit_cookies", %{"cookies" => cookies_json}, socket) do
    socket = assign(socket, submitting: true, status: {:loading, "Validating cookies..."})

    case validate_and_save(cookies_json, socket.assigns.gitlab_app, socket.assigns.group_path) do
      {:ok, session} ->
        {:noreply,
         assign(socket,
           submitting: false,
           status: {:success, "Session saved successfully. GitLab integration is now active."},
           current_session: session
         )}

      {:error, message} ->
        {:noreply,
         assign(socket,
           submitting: false,
           status: {:error, message}
         )}
    end
  end

  defp validate_and_save(cookies_json, gitlab_app, group_path) do
    with {:ok, cookies} <- parse_cookies(cookies_json),
         {:ok, _} <- call_playwright_validate(cookies, group_path) do
      expire_existing_sessions(:gitlab)

      attrs = %{
        platform: :gitlab,
        status: :active,
        workspace_url: "https://gitlab.com/groups/#{group_path}/-/group_members",
        captured_at: DateTime.utc_now(),
        application_id: gitlab_app && gitlab_app.id
      }

      case Ash.create(AccessGuardian.Catalog.IntegrationSession, attrs, action: :create) do
        {:ok, session} -> {:ok, session}
        {:error, err} -> {:error, "Failed to save session: #{inspect(err)}"}
      end
    end
  end

  defp parse_cookies(json_string) do
    case Jason.decode(json_string) do
      {:ok, cookies} when is_list(cookies) -> {:ok, cookies}
      _ -> {:error, "Invalid JSON. Make sure you exported cookies from Cookie-Editor."}
    end
  end

  defp call_playwright_validate(cookies, group_path) do
    service_url = System.get_env("PLAYWRIGHT_SERVICE_URL") || "http://playwright:3000"

    case Req.post("#{service_url}/validate-session",
           json: %{cookies: cookies, group_path: group_path},
           receive_timeout: 30_000,
           connect_options: [timeout: 5_000]
         ) do
      {:ok, %{status: 200, body: %{"success" => true}}} ->
        {:ok, :valid}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, error}

      {:ok, %{status: status, body: body}} ->
        {:error, "Playwright service returned #{status}: #{inspect(body)}"}

      {:error, %{reason: :econnrefused}} ->
        {:error, "Playwright service not available (connection refused)"}

      {:error, reason} ->
        {:error, "Playwright service error: #{inspect(reason)}"}
    end
  end

  defp expire_existing_sessions(platform) do
    case Ash.read(AccessGuardian.Catalog.IntegrationSession) do
      {:ok, sessions} ->
        sessions
        |> Enum.filter(&(&1.platform == platform and &1.status == :active))
        |> Enum.each(fn s ->
          Ash.update!(s, action: :mark_expired)
        end)

      _ ->
        :ok
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-base-content">Integration Setup</h1>
        <.link navigate="/applications" class="text-sm link link-hover text-base-content/60">
          &larr; Applications
        </.link>
      </div>

      <div :if={@current_session} class="alert alert-success mb-6">
        <div>
          <p class="font-semibold">GitLab session active</p>
          <p class="text-sm opacity-80">
            Captured: {Calendar.strftime(@current_session.captured_at, "%b %d, %Y at %H:%M UTC")}
          </p>
        </div>
      </div>

      <div :if={!@current_session} class="alert alert-warning mb-6">
        <p>No active GitLab session. Complete the setup below to enable GitLab provisioning.</p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-3">
        <p class="font-semibold text-sm text-base-content mb-1">
          <span class="badge badge-sm badge-neutral mr-1.5">1</span> Log into GitLab
        </p>
        <p class="text-sm text-base-content/60">
          Open your GitLab group members page at
          <a
            href={"https://gitlab.com/groups/#{@group_path}/-/group_members"}
            target="_blank"
            class="link link-primary"
          >
            gitlab.com/groups/{@group_path}/-/group_members
          </a>
          and make sure you are logged in as an Owner.
        </p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-3">
        <p class="font-semibold text-sm text-base-content mb-1">
          <span class="badge badge-sm badge-neutral mr-1.5">2</span> Export your cookies
        </p>
        <p class="text-sm text-base-content/60 mb-2">
          Install the
          <a href="https://cookie-editor.com" target="_blank" class="link link-primary">Cookie-Editor</a>
          browser extension. While on the GitLab members page, click the extension icon and click <strong>Export</strong> (JSON format).
        </p>
        <p class="text-xs text-base-content/40 mt-2">
          Cookie-Editor exports all cookies including httpOnly session cookies that JavaScript cannot access.
        </p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-3">
        <p class="font-semibold text-sm text-base-content mb-3">
          <span class="badge badge-sm badge-neutral mr-1.5">3</span> Paste and connect
        </p>

        <form phx-submit="submit_cookies">
          <div class="mb-3">
            <label class="label text-sm font-medium">Cookies JSON</label>
            <textarea
              name="cookies"
              placeholder="Paste the exported JSON here..."
              class="textarea textarea-bordered w-full font-mono text-xs"
              rows="5"
            ></textarea>
          </div>

          <button type="submit" class="btn btn-success w-full" disabled={@submitting}>
            {if @submitting, do: "Validating...", else: "Validate & Save Session"}
          </button>
        </form>

        <div :if={@status} class={["alert mt-4", status_class(@status)]}>
          {elem(@status, 1)}
        </div>
      </div>
    </div>
    """
  end

  defp status_class({:success, _}), do: "alert-success"
  defp status_class({:error, _}), do: "alert-error"
  defp status_class({:loading, _}), do: "alert-info"
end
