require Logger

defmodule JellyShot.Post do
  defstruct file_name: "", slug: "", authors: [], title: "", date: "", intro: "", categories: [], image: "", image_position: "center", content: ""

  def transform(file) do
    case do_transform(file) do
      {:ok, post} -> {:ok, post}
      {:error, reason} ->
        Logger.warn "Failed to compile #{file}, #{reason}"

        {:ok, struct(Post)}
    end
  end

  defp cat_errors({severity, line, error}, acc) do
    acc <> "Error at line #{line}: #{error}\n"
  end

  defp do_transform(file) do
    {:ok, matter, body} = split_frontmatter(file)
    case Earmark.as_html(body, %Earmark.Options{pedantic: false, sanitize: true}) do
      {:ok, html, _} -> {:ok, into_post(file, matter, html)}
      {:error, html, error_messages} -> 
        errors = error_messages
        |> Enum.reduce(html, &cat_errors/2)
        {:ok, into_post(file, matter, html <> "<!--" <> errors <> "-->")}
    end
  end

  defp split_frontmatter(file) do
    with{:ok, matter, body} <- parse_yaml_frontmatter(file),
        {:ok, parsed_date} <- Timex.parse(matter.date, "{ISOdate}"),
    do: {:ok, %{matter | date: parsed_date}, body}
  end

  defp parse_yaml_frontmatter(file) do
    case YamlFrontMatter.parse_file(file) do
      {:ok, {:ok, matter}, body} ->
        {:ok, Map.new(matter, fn {k, v} -> {String.to_atom(k), v} end), body}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp file_to_slug(file) do
    file |> Path.basename(file) |> String.replace(~r/\.md$/, "") |> URI.encode
  end

  defp into_post(file, meta, html) do
    data = %{
      file_name: file,
      slug: file_to_slug(file),
      content: html,
    } |> Map.merge(meta)

    struct(JellyShot.Post, data)
  end
end
