defmodule Authors do
  use HTTPoison.Base
  
  def process_response_body(body) do
    body
    |> Poison.decode!
    |> Enum.map(&Map.get(&1, "url"))
  end
end
