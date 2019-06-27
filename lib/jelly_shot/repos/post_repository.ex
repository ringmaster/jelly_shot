require Logger
require IEx

alias JellyShot.Post

defmodule JellyShot.PostRepository do
  def start_link(source) do
    use JellyShot.Watcher, [module: __MODULE__, source: source]

    :ets.new(:posts, [:ordered_set, :public, :named_table])
    :ets.new(:categories, [:bag, :public, :named_table])
    :ets.new(:authors, [:bag, :public, :named_table])
    :ets.new(:files, [:bag, :public, :named_table])

    source
      |> get_initial_state
      |> Enum.each(fn(item) ->
        item = if Enum.count(item.categories) == 0 do
          Map.put(item, :categories, ["untagged"])
        else
          item
        end
        upsert_by_post(item)
      end)

    Agent.start_link(fn -> "table" end, name: __MODULE__)
  end

  def anew(source), do: Agent.update(__MODULE__, fn (_state) -> read_all_posts source end)

  def page({:ok, posts}, page), do: page(posts, page)
  def page(posts, page) do
    posts
    |> Enum.chunk_every(5)
    |> Enum.at(page, [])
    |> (fn(a) -> {:ok, a} end).()
  end

  def list do
    :ets.match(:posts, {:_, :"$1"})
      |> List.flatten
      |> Enum.reverse
      |> (fn(a) -> {:ok, a} end).()
  end

  def categories do
    :ets.match(:categories, {:"$1", :_})
      |> List.flatten
      |> Enum.reduce(%{}, fn(item, acc) ->
        Map.update(acc, item, 1, fn(x) -> x + 1 end)
      end)
      |> (fn(a) -> {:ok, a} end).()
  end

  def get_by_slug(slug) do
    case :ets.match(:posts, {{:_, slug}, :"$1"}) |> List.flatten do
      [post | _] -> {:ok, post}
      _ -> :not_found
    end
  end

  def get_by_category(category) do
    :ets.match(:categories, {category, :"$1"})
      |> List.flatten
      |> Enum.map(fn(dateslug) ->
        [{_, post} | _] = :ets.lookup(:posts, dateslug) |> List.flatten
        post
      end)
      |> (fn(a) -> {:ok, a} end).()
  end

  def get_by_author(author) do
    :ets.match(:authors, {author, :"$1"})
      |> List.flatten
      |> Enum.map(fn(dateslug) ->
        [{_, post} | _] = :ets.lookup(:posts, dateslug) |> List.flatten
        post
      end)
      |> (fn(a) -> {:ok, a} end).()
  end

  def get_by_filename(filename) do
    :ets.match(:files, {filename, :"$1"})
      |> List.flatten
      |> Enum.map(fn(dateslug) ->
        [{_, post} | _] = :ets.lookup(:posts, dateslug) |> List.flatten
        post
      end)
      |> (fn(a) -> {:ok, a} end).()
  end

  def upsert_by_file_name(file_name) do
    case Post.transform(file_name) do
      {:ok, post} ->
        upsert_by_post(post)
      {:error, _} -> :ignored
    end
  end

  def date_slug(post) do
    {NaiveDateTime.to_erl(post.date), post.slug}
  end

  def upsert_by_post(post) do
    date_slug = date_slug(post)
    :ets.insert(:posts, {date_slug, post})
    post.categories
      |> Enum.each(fn(category) ->
        :ets.insert(:categories, {category, date_slug})
      end)
    post.authors
      |> Enum.each(fn(author) ->
        :ets.insert(:authors, {author, date_slug})
      end)
    :ets.insert(:files, {post.file_name, date_slug})
    post
  end

  def delete_by_file_name(file_name) do
    post_slug = file_name |> get_by_filename() |> date_slug()
    :ets.delete(:posts, post_slug)
    # Need to figure out how to remove the values from :categories, :authors, and :files
  end

  defp read_all_posts(source) do
    source
      |> File.ls!
      |> Enum.map(&(Path.join([source, &1])))
      |> Flow.from_enumerable(max_demand: 1)
      |> Flow.filter(&(Path.extname(&1) == ".md"))
      |> Flow.map(&Post.transform/1)
      |> Flow.partition
      |> Flow.reduce(fn -> [] end, &valid_into_list/2)
      |> Enum.sort(&sort/2)
  end

  defp get_initial_state(source) do
    start = Timex.now()
    posts = read_all_posts source

    Logger.debug fn -> "Compiled #{Enum.count(posts)} posts in #{Timex.diff Timex.now(), start, :milliseconds}ms." end

    posts
  end

  defp valid_into_list(item, acc) do
    case item do
      {:ok, post} -> acc ++ [post]
      {:error, _} -> acc
    end
  end

  defp sort(a, b), do: Timex.compare(a.date, b.date) > 0
end
