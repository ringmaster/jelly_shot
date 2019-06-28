require Logger

defmodule JellyShot.Watcher do
  use GenServer

  defmacro __using__(options) do
    quote bind_quoted: [options: options] do
      case JellyShot.Watcher.start_link(options) do
        {:ok, _pid} -> Logger.debug fn -> "Watching #{options[:source]} for #{options[:module]}" end
        _ -> nil
      end
    end
  end

  def start_link(options) do
    only = Macro.expand(options, __ENV__)[:only]
    name = to_string(options[:module]) <> ".Watcher" |> String.to_atom

    if !only && Mix.env == :dev || only == Mix.env do
      GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  def init(options) do
    repo = Macro.expand options, __ENV__
    path = Path.expand repo[:source]
    name = to_string(options[:module]) <> ".FS" |> String.to_atom

    {:ok, _pid}  = :fs.start_link(name, path)
    :ok = :fs.subscribe(name)

    {:ok, {repo, []}}
  end

  def handle_info({_pid, {:fs, :file_event}, {path, events}}, {repo, state}) do
    [module: module, source: source] = repo

    if Path.extname(path) == ".md" do
      cond do
        :modified in events -> module.upsert_by_file_name(path)
        :removed in events -> module.delete_by_file_name(path)
        :created in events -> module.upsert_by_file_name(path)
        :renamed in events -> module.upsert_by_file_name(path)
        true -> Enum.each(events, fn(event) -> Logger.info("Didn't handle file event " <> to_string(event)) end )
      end
    else
      Logger.info("The unchecked path is #{path}")
    end

    {:noreply, {repo, state}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
