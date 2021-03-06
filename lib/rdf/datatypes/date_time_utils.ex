defmodule RDF.DateTimeUtils do
  @moduledoc false

  def tz(string) do
    case Regex.run(~r/([+-])(\d\d:\d\d)/, string) do
      [_, sign, zone] ->
        sign <> zone
      _ ->
        if String.ends_with?(string, "Z") do
          "Z"
        else
          ""
        end
    end
  end

end
