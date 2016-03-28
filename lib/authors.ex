defmodule Authors do
  use HTTPoison.Base
  
  def process_response_body(body) do
    body
    |> Poison.decode!
  end

  def request_contributor_urls(repo, user, password) do
    Authors.get!("https://" <> user <> ":" <> password <> "@api.github.com/repos/" <> repo <> "/contributors")
    |> Map.get(:body)
    |> Enum.map(&Map.get(&1, "url"))
  end
  
  def get_name_and_email(contributor_url, user, password) do
    String.replace(contributor_url, ~r(https://), "https://" <> user <> ":" <> password <> "@")
    |> Authors.get!
    |> Map.get(:body)
  end
  
  def request_contributor_details(contributor_urls, user, password) do
    contributor_urls
    |> Enum.map(&Task.async(fn -> get_name_and_email(&1, user, password) end))
    |> Enum.map(&Task.await(&1, 10000))
  end

  def contributor_to_string(contributor) do
    IO.inspect(contributor)
    %{"name" => name, "email" => email, "url" => url, "login" => login} = contributor
    email = if email, do: " <" <> email <> ">", else: ""
    (name || login) <> email <> " (" <> url <> ")"
  end
  
  def write_to_authors_file(contributors_list) do
    contributor_list = contributors_list
    |> Enum.map(&contributor_to_string(&1))
    |> Enum.join("\n")
    
    File.write("AUTHORS", contributor_list)
  end

  def make_authors_file(repo, user, password) do
    request_contributor_urls(repo, user, password)
    |> request_contributor_details(user, password)
    |> write_to_authors_file
  end
end
