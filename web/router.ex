defmodule JellyShot.Router do
  use JellyShot.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JellyShot do
    pipe_through :browser # Use the default browser stack

    get "/", PostController, :index
    get "/posts", PostController, :index
    get "/posts/:slug", PostController, :show
    get "/page/:page", PostController, :index
    get "/tag/:category", PostController, :tag

    get "/pages/:slug", PageController, :show

    get "/_webhook", WebhookController, :fire

    # Should get rid of this stuff that is plaguing Asymptomatic
    get "/:postid/:hash/redirect", PageController, :fourohfour

    # This has to be last or it catches other things
    get "/:slug", PageController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", JellyShot do
  #   pipe_through :api
  # end
end
