defmodule AccessGuardian.Slack.ApiBehaviour do
  @callback post_message(channel :: String.t(), blocks :: list(), opts :: keyword()) ::
              :ok | {:error, term()}
  @callback open_modal(trigger_id :: String.t(), view :: map()) ::
              :ok | {:error, term()}
  @callback update_message(channel :: String.t(), ts :: String.t(), blocks :: list()) ::
              :ok | {:error, term()}
  @callback get_user_info(user_id :: String.t()) ::
              {:ok, map()} | {:error, term()}
end
