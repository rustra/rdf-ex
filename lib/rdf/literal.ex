defmodule RDF.Literal do
  @moduledoc """
  RDF literals are leaf nodes of a RDF graph containing raw data, like strings and numbers.
  """

  defstruct [:value, :uncanonical_lexical, :datatype, :language]

  @type t :: module

  alias RDF.Datatype.NS.XSD

  # to be able to pattern-match on plain types; we can't use RDF.Literal.Guards here since these aren't compiled here yet
  @xsd_string  XSD.string
  @lang_string RDF.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#langString")
  @plain_types [@xsd_string, @lang_string]


  @doc """
  Creates a new `RDF.Literal` of the given value and tries to infer an appropriate XSD datatype.

  Note: The `RDF.literal` function is a shortcut to this function.

  The following mapping of Elixir types to XSD datatypes is applied:

  | Elixir datatype | XSD datatype   |
  | :-------------- | :------------- |
  | `string`        | `xsd:string`   |
  | `boolean`       | `xsd:boolean`  |
  | `integer`       | `xsd:integer`  |
  | `float`         | `xsd:double`   |
  | `Time`          | `xsd:time`     |
  | `Date`          | `xsd:date`     |
  | `DateTime`      | `xsd:dateTime` |
  | `NaiveDateTime` | `xsd:dateTime` |


  ## Examples

      iex> RDF.Literal.new(42)
      %RDF.Literal{value: 42, datatype: XSD.integer}

  """
  def new(value)

  def new(%RDF.Literal{} = literal),     do: literal

  def new(value) when is_binary(value),  do: RDF.String.new(value)
  def new(value) when is_boolean(value), do: RDF.Boolean.new(value)
  def new(value) when is_integer(value), do: RDF.Integer.new(value)
  def new(value) when is_float(value),   do: RDF.Double.new(value)
  def new(%Decimal{} = value),           do: RDF.Decimal.new(value)

  def new(%Date{} = value),              do: RDF.Date.new(value)
  def new(%Time{} = value),              do: RDF.Time.new(value)
  def new(%DateTime{} = value),          do: RDF.DateTime.new(value)
  def new(%NaiveDateTime{} = value),     do: RDF.DateTime.new(value)


  def new(value) do
    raise RDF.Literal.InvalidError, "#{inspect value} not convertible to a RDF.Literal"
  end

  @doc """
  Creates a new `RDF.Literal` with the given datatype or language tag.
  """
  def new(value, opts)

  def new(value, opts) when is_list(opts),
    do: new(value, Map.new(opts))

  def new(value, %{language: nil} = opts),
    do: new(value, Map.delete(opts, :language))

  def new(value, %{language: _} = opts) do
    if is_binary(value) do
      if opts[:datatype] in [nil, @lang_string] do
        RDF.LangString.new(value, opts)
      else
        raise ArgumentError, "datatype with language must be rdf:langString"
      end
    else
      new(value, Map.delete(opts, :language)) # Should we raise a warning?
    end
  end

  def new(value, %{datatype: %RDF.IRI{} = id} = opts) do
    case RDF.Datatype.get(id) do
      nil      -> %RDF.Literal{value: value, datatype: id}
      datatype -> datatype.new(value, opts)
    end
  end

  def new(value, %{datatype: datatype} = opts),
    do: new(value, %{opts | datatype: RDF.iri(datatype)})

  def new(value, opts) when is_map(opts) and map_size(opts) == 0,
    do: new(value)


  @doc """
  Creates a new `RDF.Literal`, but fails if it's not valid.

  Note: Validation is only possible if an `RDF.Datatype` with an implementation of
    `RDF.Datatype.valid?/1` exists.

  ## Examples

      iex> RDF.Literal.new!("3.14", datatype: XSD.double) == RDF.Literal.new("3.14", datatype: XSD.double)
      true

      iex> RDF.Literal.new!("invalid", datatype: "http://example/unkown_datatype") == RDF.Literal.new("invalid", datatype: "http://example/unkown_datatype")
      true

      iex> RDF.Literal.new!("foo", datatype: XSD.integer)
      ** (RDF.Literal.InvalidError) invalid RDF.Literal: %RDF.Literal{value: nil, lexical: "foo", datatype: ~I<http://www.w3.org/2001/XMLSchema#integer>}

      iex> RDF.Literal.new!("foo", datatype: RDF.langString)
      ** (RDF.Literal.InvalidError) invalid RDF.Literal: %RDF.Literal{value: "foo", datatype: ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#langString>, language: nil}

  """
  def new!(value, opts \\ %{}) do
    with %RDF.Literal{} = literal <- new(value, opts) do
      if valid?(literal) do
        literal
      else
        raise RDF.Literal.InvalidError, "invalid RDF.Literal: #{inspect literal}"
      end
    else
      invalid ->
        raise RDF.Literal.InvalidError, "invalid result of RDF.Literal.new: #{inspect invalid}"
    end
  end

  @doc """
  Returns the lexical representation of the given literal according to its datatype.
  """
  def lexical(%RDF.Literal{value: value, uncanonical_lexical: nil, datatype: id} = literal) do
    case RDF.Datatype.get(id) do
      nil      -> to_string(value)
      datatype -> datatype.lexical(literal)
    end
  end

  def lexical(%RDF.Literal{uncanonical_lexical: lexical}), do: lexical

  @doc """
  Returns the given literal in its canonical lexical representation.
  """
  def canonical(%RDF.Literal{uncanonical_lexical: nil} = literal), do: literal
  def canonical(%RDF.Literal{datatype: id} = literal) do
    case RDF.Datatype.get(id) do
      nil      -> literal
      datatype -> datatype.canonical(literal)
    end
  end


  @doc """
  Returns if the given literal is in its canonical lexical representation.
  """
  def canonical?(%RDF.Literal{uncanonical_lexical: nil}), do: true
  def canonical?(_),                                      do: false


  @doc """
  Returns if the value of the given literal is a valid according to its datatype.
  """
  def valid?(%RDF.Literal{datatype: id} = literal) do
    case RDF.Datatype.get(id) do
      nil      -> true
      datatype -> datatype.valid?(literal)
    end
  end


  @doc """
  Returns if a literal is a simple literal.

  A simple literal has no datatype or language.

  see <http://www.w3.org/TR/sparql11-query/#simple_literal>
  """
  def simple?(%RDF.Literal{datatype: @xsd_string}), do: true
  def simple?(_), do: false


  @doc """
  Returns if a literal is a language-tagged literal.

  see <http://www.w3.org/TR/rdf-concepts/#dfn-plain-literal>
  """
  def has_language?(%RDF.Literal{datatype: @lang_string}), do: true
  def has_language?(_), do: false


  @doc """
  Returns if a literal is a datatyped literal.

  For historical reasons, this excludes `xsd:string` and `rdf:langString`.

  see <http://www.w3.org/TR/rdf-concepts/#dfn-typed-literal>
  """
  def has_datatype?(literal) do
    not plain?(literal) and not has_language?(literal)
  end


  @doc """
  Returns if a literal is a plain literal.

  A plain literal may have a language, but may not have a datatype.
  For all practical purposes, this includes `xsd:string` literals too.

  see <http://www.w3.org/TR/rdf-concepts/#dfn-plain-literal>
  """
  def plain?(%RDF.Literal{datatype: datatype})
    when datatype in @plain_types, do: true
  def plain?(_), do: false

  def typed?(literal), do: not plain?(literal)


  @doc """
  Checks if two `RDF.Literal`s are equal.

  Non-RDF terms are tried to be coerced via `RDF.Term.coerce/1` before comparison.

  Returns `nil` when the given arguments are not comparable as Literals.

  see <https://www.w3.org/TR/rdf-concepts/#section-Literal-Equality>
  """
  def equal_value?(left, right)

  def equal_value?(%RDF.Literal{datatype: id1} = literal1, %RDF.Literal{datatype: id2} = literal2) do
    case RDF.Datatype.get(id1) do
      nil ->
        if id1 == id2 do
          literal1.value == literal2.value
        end
      datatype ->
        datatype.equal_value?(literal1, literal2)
    end
  end

  # TODO: Handle AnyURI in its own RDF.Datatype implementation
  @xsd_any_uri "http://www.w3.org/2001/XMLSchema#anyURI"

  def equal_value?(%RDF.Literal{datatype: %RDF.IRI{value: @xsd_any_uri}} = left, right),
    do: RDF.IRI.equal_value?(left, right)

  def equal_value?(left, %RDF.Literal{datatype: %RDF.IRI{value: @xsd_any_uri}} = right),
    do: RDF.IRI.equal_value?(left, right)

  def equal_value?(%RDF.Literal{} = left, right) when not is_nil(right) do
    unless RDF.Term.term?(right) do
      equal_value?(left, RDF.Term.coerce(right))
    end
  end

  def equal_value?(_, _), do: nil


  @doc """
  Checks if the first of two `RDF.Literal`s is smaller then the other.

  Returns `nil` when the given arguments are not comparable datatypes.

  """
  def less_than?(literal1, literal2) do
    case compare(literal1, literal2) do
      :lt -> true
      nil -> nil
      _   -> false
    end
  end

  @doc """
  Checks if the first of two `RDF.Literal`s is greater then the other.

  Returns `nil` when the given arguments are not comparable datatypes.

  """
  def greater_than?(literal1, literal2) do
    case compare(literal1, literal2) do
      :gt -> true
      nil -> nil
      _   -> false
    end
  end


  @doc """
  Compares two `RDF.Literal`s.

  Returns `:gt` if first literal is greater than the second in terms of their datatype
  and `:lt` for vice versa. If the two literals are equal `:eq` is returned.
  For datatypes with only partial ordering `:indeterminate` is returned when the
  order of the given literals is not defined.

  Returns `nil` when the given arguments are not comparable datatypes.

  """
  def compare(left, right)

  def compare(%RDF.Literal{datatype: id1} = literal1, %RDF.Literal{datatype: id2} = literal2) do
    case RDF.Datatype.get(id1) do
      nil ->
        if id1 == id2 do
          cond do
            literal1.value == literal2.value -> :eq
            literal1.value < literal2.value  -> :lt
            true                             -> :gt
          end
        end

      datatype ->
        datatype.compare(literal1, literal2)
    end
  end

  def compare(_, _), do: nil


  @doc """
  Matches the string representation of the given value against a XPath and XQuery regular expression pattern.

  The regular expression language is defined in _XQuery 1.0 and XPath 2.0 Functions and Operators_.

  The `pattern` and the optional `flags` can be given as an Elixir string or as
  `xsd:string` `RDF.Literal`s.

  see <https://www.w3.org/TR/xpath-functions/#func-matches>
  """
  def matches?(value, pattern, flags \\ "") do
    string = to_string(value)
    case xpath_pattern(pattern, flags) do
      {:regex, regex} ->
        Regex.match?(regex, string)

      {:q, pattern} ->
        String.contains?(string, pattern)

      {:qi, pattern} ->
        string
        |> String.downcase()
        |> String.contains?(String.downcase(pattern))

      _ ->
        raise "Invalid XQuery regex pattern or flags"
    end
  end

  @doc false
  def xpath_pattern(pattern, flags)

  def xpath_pattern(%RDF.Literal{datatype: @xsd_string} = pattern, flags),
    do: xpath_pattern(pattern.value, flags)

  def xpath_pattern(pattern, %RDF.Literal{datatype: @xsd_string} = flags),
    do: xpath_pattern(pattern, flags.value)

  def xpath_pattern(pattern, flags) when is_binary(pattern) and is_binary(flags) do
    q_pattern(pattern, flags) || xpath_regex_pattern(pattern, flags)
  end

  defp q_pattern(pattern, flags) do
    if String.contains?(flags, "q") and String.replace(flags, ~r/[qi]/, "") == "" do
      {(if String.contains?(flags, "i"), do: :qi, else: :q), pattern}
    end
  end

  defp xpath_regex_pattern(pattern, flags) do
    with {:ok, regex} <-
           pattern
           |> convert_utf_escaping()
           |> Regex.compile(xpath_regex_flags(flags)) do
      {:regex, regex}
    end
  end

  @doc false
  def convert_utf_escaping(string) do
    require Integer

    xpath_unicode_regex = ~r/(\\*)\\U([0-9]|[A-F]|[a-f]){2}(([0-9]|[A-F]|[a-f]){6})/
    [first | possible_matches] =
      Regex.split(xpath_unicode_regex, string, include_captures: true)

    [first |
      Enum.map_every(possible_matches, 2, fn possible_xpath_unicode ->
        [_, escapes, _, codepoint, _] = Regex.run(xpath_unicode_regex, possible_xpath_unicode)
        if escapes |> String.length() |> Integer.is_odd() do
          "#{escapes}\\u{#{codepoint}}"
        else
          "\\" <> possible_xpath_unicode
        end
      end)
    ]
    |> Enum.join()
  end

  defp xpath_regex_flags(flags) do
    String.replace(flags, "q", "") <> "u"
  end
end

defimpl String.Chars, for: RDF.Literal do
  def to_string(literal) do
    RDF.Literal.lexical(literal)
  end
end
