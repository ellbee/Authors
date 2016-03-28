defmodule Authors do
  def get!(url) do
    HTTPoison.get!(url)
    |> Map.get(:body)
    |> Poison.decode!
  end

  def request_contributor_urls(repo, user, password) do
    Authors.get!("https://" <> user <>
      ":" <> password <> "@api.github.com/repos/" <>
      repo <> "/contributors")
    |> Enum.map(&Map.get(&1, "url"))
  end

  def request_contributor(contributor_url, user, password) do
    String.replace(contributor_url, ~r(https://),
      "https://" <> user <> ":" <> password <> "@")
    |> Authors.get!
  end

  def request_contributors(contributor_urls, user, password) do
    contributor_urls
    |> Enum.map(&Task.async(fn -> request_contributor(&1, user, password) end))
    |> Enum.map(&Task.await(&1, 10000))
  end

  def contributor_to_string(
    %{"name" => name, "email" => email, "url" => url, "login" => login}
  ) do
    email = if email, do: " <" <> email <> ">", else: ""
    (name || login) <> email <> " (" <> url <> ")"
  end

  def write_to_authors_file(contributors_list) do
    contributor_list = contributors_list
    |> Enum.map(&contributor_to_string(&1))
    |> Enum.join("\n")

    File.mkdir_p!("out")
    File.cd!("out", fn ->
      File.write!("AUTHORS", contributor_list)
    end)
  end

  def make_authors_file(repo, user, password) do
    request_contributor_urls(repo, user, password)
    |> request_contributors(user, password)
    |> write_to_authors_file
  end

  def main(args) do
    {[user: user, password: password], [repo], []} = OptionParser.parse(args)
    make_authors_file(repo, user, password)
  end
end
