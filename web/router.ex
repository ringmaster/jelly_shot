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
    get "/:slug", PageController, :show

    get "/:postid/:hash/redirect", PageController, :fourohfour
  end

  # Other scopes may use custom stacks.
  # scope "/api", JellyShot do
  #   pipe_through :api
  # end
end
