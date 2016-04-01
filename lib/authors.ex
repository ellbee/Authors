defmodule Authors do

  @spec get!(String.t) :: [map()]
  def get!(url) do
    HTTPoison.get!(url)
    |> Map.get(:body)
    |> Poison.decode!
  end

  @spec make_url(String.t, String.t, String.t) :: String.t
  def make_url(url, "", "") do
    url
  end

  def make_url(url, user, password) do
    String.replace(url, ~r(https://), "https://" <> user <> ":" <> password <> "@")
  end

  @spec request_contributor_urls(String.t, String.t, String.t) :: [map()]
  def request_contributor_urls(repo, user, password) do
    "https://api.github.com/repos/" <> repo <> "/contributors"
    |> make_url(user, password)
    |> Authors.get!
    |> Enum.map(&Map.get(&1, "url"))
  end

  @spec request_contributor(String.t, String.t, String.t) :: map()
  def request_contributor(contributor_url, user, password) do
    make_url(contributor_url, user, password)
    |> Authors.get!
  end

  @spec request_contributors([map()], String.t, String.t) :: [map()]
  def request_contributors(contributor_urls, user, password) do
    contributor_urls
    |> Enum.map(&Task.async(fn -> request_contributor(&1, user, password) end))
    |> Enum.map(&Task.await(&1, 10000))
  end

  @spec contributor_to_string(map()) :: String.t
  def contributor_to_string(
    %{"name" => name, "email" => email, "url" => url, "login" => login}
  ) do
    email = if email, do: " <" <> email <> ">", else: ""
    (name || login) <> email <> " (" <> url <> ")"
  end

  @spec write_to_authors_file([map()]) :: tuple()
  def write_to_authors_file(contributors_list) do
    contributor_list = contributors_list
    |> Enum.map(&contributor_to_string(&1))
    |> Enum.join("\n")

    File.mkdir_p!("out")
    File.cd!("out", fn ->
      File.write!("AUTHORS", contributor_list)
    end)
  end

  @spec make_authors_file(String.t, String.t, String.t) :: tuple()
  def make_authors_file(repo, user, password) do
    request_contributor_urls(repo, user, password)
    |> request_contributors(user, password)
    |> write_to_authors_file
  end

  def main(args) do
    case OptionParser.parse(args) do
      {[user: user, password: password], [repo], []} ->
        make_authors_file(repo, user, password)
      {[], [repo], []} ->
        make_authors_file(repo, "", "")
    end
  end
end
