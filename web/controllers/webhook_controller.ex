require Logger

defmodule JellyShot.WebhookController do
  use JellyShot.Web, :controller

  def fire(conn, _) do
    {result, code} = System.cmd("git", ["pull"], cd: File.cwd! <> "/priv/posts")
    json(conn, %{result: result, code: code})
  end
end
