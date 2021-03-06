defmodule RDF.Double do
  @moduledoc """
  `RDF.Datatype` for XSD double.
  """

  use RDF.Datatype, id: RDF.Datatype.NS.XSD.double

  import RDF.Literal.Guards


  def build_literal_by_value(value, opts) do
    case convert(value, opts) do
      float when is_float(float) ->
        build_literal(float, decimal_form(float), opts)
      nil ->
        build_literal(nil, invalid_lexical(value), opts)
      special_value when is_atom(special_value) ->
        build_literal(special_value, nil, opts)
    end
  end

  @impl RDF.Datatype
  def convert(value, opts)

  def convert(value, _) when is_float(value),   do: value

  def convert(value, _) when is_integer(value), do: value / 1

  def convert(value, opts) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} ->
        float
      {float, remainder}  ->
        # 1.E-8 is not a valid Elixir float literal and consequently not fully parsed with Float.parse
        if Regex.match?(~r/^\.e?[\+\-]?\d+$/i, remainder) do
          convert(to_string(float) <> String.trim_leading(remainder, "."), opts)
        else
          super(value, opts)
        end
      :error ->
        case String.upcase(value) do
          "INF"   -> :positive_infinity
          "-INF"  -> :negative_infinity
          "NAN"   -> :nan
          _       -> super(value, opts)
        end
    end
  end

  def convert(value, _)
    when value in ~W[positive_infinity negative_infinity nan]a,
    do: value

  def convert(value, opts), do: super(value, opts)


  @impl RDF.Datatype
  def canonical_lexical(value)

  def canonical_lexical(:nan),                       do: "NaN"
  def canonical_lexical(:positive_infinity),         do: "INF"
  def canonical_lexical(:negative_infinity),         do: "-INF"
  def canonical_lexical(float) when is_float(float), do: exponential_form(float)
  def canonical_lexical(value),                      do: to_string(value)


  defp decimal_form(float) when is_float(float) do
    to_string(float)
  end

  defp exponential_form(float) when is_float(float) do
    # Can't use simple %f transformation due to special requirements from
    # N3 tests in representation
    [i, f, e] =
      float
      |> float_to_string()
      |> String.split(~r/[\.e]/)
    f =
      case String.replace(f, ~r/0*$/, "", global: false) do # remove any trailing zeroes
        "" -> "0" # ...but there must be a digit to the right of the decimal point
        f  -> f
      end
    e = String.trim_leading(e, "+")
    "#{i}.#{f}E#{e}"
  end

  if List.to_integer(:erlang.system_info(:otp_release)) >= 21 do
    defp float_to_string(float) do
      :io_lib.format("~.15e", [float])
      |> to_string()
    end
  else
    defp float_to_string(float) do
      :io_lib.format("~.15e", [float])
      |> List.first
      |> to_string()
    end
  end


  @impl RDF.Datatype
  def cast(literal)

  def cast(%RDF.Literal{datatype: datatype} = literal) do
    cond do
      not RDF.Literal.valid?(literal) ->
        nil

      is_xsd_double(datatype) ->
        literal

      literal == RDF.false ->
        new(0.0)

      literal == RDF.true ->
        new(1.0)

      is_xsd_string(datatype) ->
        literal.value
        |> new()
        |> canonical()
        |> validate_cast()

      is_xsd_decimal(datatype) ->
        literal.value
        |> Decimal.to_float()
        |> new()

      is_xsd_integer(datatype) or is_xsd_float(datatype) ->
        new(literal.value)

      true ->
        nil
    end
  end

  def cast(_), do: nil


  @impl RDF.Datatype
  def equal_value?(left, right), do: RDF.Numeric.equal_value?(left, right)

  @impl RDF.Datatype
  def compare(left, right), do: RDF.Numeric.compare(left, right)

end
