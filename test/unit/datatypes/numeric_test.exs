defmodule RDF.NumericTest do
  use RDF.Test.Case

  alias RDF.Numeric
  alias RDF.NS.XSD
  alias Decimal, as: D

  @positive_infinity RDF.double(:positive_infinity)
  @negative_infinity RDF.double(:negative_infinity)
  @nan RDF.double(:nan)


  @negative_zeros ~w[
    -0
    -000
    -0.0
    -0.00000
  ]

  test "negative_zero?/1" do
    Enum.each @negative_zeros, fn negative_zero ->
      assert Numeric.negative_zero?(RDF.double(negative_zero))
      assert Numeric.negative_zero?(RDF.decimal(negative_zero))
    end

    refute Numeric.negative_zero?(RDF.double("-0.00001"))
    refute Numeric.negative_zero?(RDF.decimal("-0.00001"))
  end

  test "zero?/1" do
    assert Numeric.zero?(RDF.integer(0))
    assert Numeric.zero?(RDF.integer("0"))

    ~w[
      0
      000
      0.0
      00.00
    ]
    |> Enum.each(fn positive_zero ->
      assert Numeric.zero?(RDF.double(positive_zero))
      assert Numeric.zero?(RDF.decimal(positive_zero))
    end)

    Enum.each @negative_zeros, fn negative_zero ->
      assert Numeric.zero?(RDF.double(negative_zero))
      assert Numeric.zero?(RDF.decimal(negative_zero))
    end

    refute Numeric.zero?(RDF.double("-0.00001"))
    refute Numeric.zero?(RDF.decimal("-0.00001"))
  end

  describe "add/2" do
    test "xsd:integer literal + xsd:integer literal" do
      assert Numeric.add(RDF.integer(1), RDF.integer(2)) == RDF.integer(3)
    end

    test "xsd:decimal literal + xsd:integer literal" do
      assert Numeric.add(RDF.decimal(1.1), RDF.integer(2)) == RDF.decimal(3.1)
    end

    test "xsd:double literal + xsd:integer literal" do
      result   = Numeric.add(RDF.double(1.1), RDF.integer(2))
      expected = RDF.double(3.1)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "xsd:decimal literal + xsd:double literal" do
      result   = Numeric.add(RDF.decimal(1.1), RDF.double(2.2))
      expected = RDF.double(3.3)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "if one of the operands is a zero or a finite number and the other is INF or -INF, INF or -INF is returned" do
      assert Numeric.add(@positive_infinity, RDF.double(0)) == @positive_infinity
      assert Numeric.add(@positive_infinity, RDF.double(3.14)) == @positive_infinity
      assert Numeric.add(RDF.double(0), @positive_infinity) == @positive_infinity
      assert Numeric.add(RDF.double(3.14), @positive_infinity) == @positive_infinity

      assert Numeric.add(@negative_infinity, RDF.double(0)) == @negative_infinity
      assert Numeric.add(@negative_infinity, RDF.double(3.14)) == @negative_infinity
      assert Numeric.add(RDF.double(0), @negative_infinity) == @negative_infinity
      assert Numeric.add(RDF.double(3.14), @negative_infinity) == @negative_infinity
    end

    test "if both operands are INF, INF is returned" do
      assert Numeric.add(@positive_infinity, @positive_infinity) == @positive_infinity
    end

    test "if both operands are -INF, -INF is returned" do
      assert Numeric.add(@negative_infinity, @negative_infinity) == @negative_infinity
    end

    test "if one of the operands is INF and the other is -INF, NaN is returned" do
      assert Numeric.add(@positive_infinity, @negative_infinity) == RDF.double(:nan)
      assert Numeric.add(@negative_infinity, @positive_infinity) == RDF.double(:nan)
    end

    test "coercion" do
      assert Numeric.add(1, 2)     == RDF.integer(3)
      assert Numeric.add(3.14, 42) == RDF.double(45.14)
      assert RDF.decimal(3.14) |> Numeric.add(42) == RDF.decimal(45.14)
      assert Numeric.add(42, RDF.decimal(3.14)) == RDF.decimal(45.14)
      assert Numeric.add(42, ~B"foo")   == nil
      assert Numeric.add(42, :foo)   == nil
      assert Numeric.add(:foo, 42)   == nil
      assert Numeric.add(:foo, :bar) == nil
    end
  end


  describe "subtract/2" do
    test "xsd:integer literal - xsd:integer literal" do
      assert Numeric.subtract(RDF.integer(3), RDF.integer(2)) == RDF.integer(1)
    end

    test "xsd:decimal literal - xsd:integer literal" do
      assert Numeric.subtract(RDF.decimal(3.3), RDF.integer(2)) == RDF.decimal(1.3)
    end

    test "xsd:double literal - xsd:integer literal" do
      result   = Numeric.subtract(RDF.double(3.3), RDF.integer(2))
      expected = RDF.double(1.3)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "xsd:decimal literal - xsd:double literal" do
      result   = Numeric.subtract(RDF.decimal(3.3), RDF.double(2.2))
      expected = RDF.double(1.1)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "if one of the operands is a zero or a finite number and the other is INF or -INF, an infinity of the appropriate sign is returned" do
      assert Numeric.subtract(@positive_infinity, RDF.double(0)) == @positive_infinity
      assert Numeric.subtract(@positive_infinity, RDF.double(3.14)) == @positive_infinity
      assert Numeric.subtract(RDF.double(0), @positive_infinity) == @negative_infinity
      assert Numeric.subtract(RDF.double(3.14), @positive_infinity) == @negative_infinity

      assert Numeric.subtract(@negative_infinity, RDF.double(0)) == @negative_infinity
      assert Numeric.subtract(@negative_infinity, RDF.double(3.14)) == @negative_infinity
      assert Numeric.subtract(RDF.double(0), @negative_infinity) == @positive_infinity
      assert Numeric.subtract(RDF.double(3.14), @negative_infinity) == @positive_infinity
    end

    test "if both operands are INF or -INF, NaN is returned" do
      assert Numeric.subtract(@positive_infinity, @positive_infinity) == RDF.double(:nan)
      assert Numeric.subtract(@negative_infinity, @negative_infinity) == RDF.double(:nan)
    end

    test "if one of the operands is INF and the other is -INF, an infinity of the appropriate sign is returned" do
      assert Numeric.subtract(@positive_infinity, @negative_infinity) == @positive_infinity
      assert Numeric.subtract(@negative_infinity, @positive_infinity) == @negative_infinity
    end

    test "coercion" do
      assert Numeric.subtract(2, 1)     == RDF.integer(1)
      assert Numeric.subtract(42, 3.14) == RDF.double(38.86)
      assert RDF.decimal(3.14) |> Numeric.subtract(42) == RDF.decimal(-38.86)
      assert Numeric.subtract(42, RDF.decimal(3.14))   == RDF.decimal(38.86)
    end
  end


  describe "multiply/2" do
    test "xsd:integer literal * xsd:integer literal" do
      assert Numeric.multiply(RDF.integer(2), RDF.integer(3)) == RDF.integer(6)
    end

    test "xsd:decimal literal * xsd:integer literal" do
      assert Numeric.multiply(RDF.decimal(1.5), RDF.integer(3)) == RDF.decimal(4.5)
    end

    test "xsd:double literal * xsd:integer literal" do
      result   = Numeric.multiply(RDF.double(1.5), RDF.integer(3))
      expected = RDF.double(4.5)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "xsd:decimal literal * xsd:double literal" do
      result   = Numeric.multiply(RDF.decimal(0.5), RDF.double(2.5))
      expected = RDF.double(1.25)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "if one of the operands is a zero and the other is an infinity, NaN is returned" do
      assert Numeric.multiply(@positive_infinity, RDF.double(0.0)) == @nan
      assert Numeric.multiply(RDF.integer(0), @positive_infinity) == @nan
      assert Numeric.multiply(RDF.decimal(0), @positive_infinity) == @nan

      assert Numeric.multiply(@negative_infinity, RDF.double(0)) == @nan
      assert Numeric.multiply(RDF.integer(0), @negative_infinity) == @nan
      assert Numeric.multiply(RDF.decimal(0.0), @negative_infinity) == @nan
    end

    test "if one of the operands is a non-zero number and the other is an infinity, an infinity with the appropriate sign is returned" do
      assert Numeric.multiply(@positive_infinity, RDF.double(3.14))  == @positive_infinity
      assert Numeric.multiply(RDF.double(3.14), @positive_infinity)  == @positive_infinity
      assert Numeric.multiply(@positive_infinity, RDF.double(-3.14)) == @negative_infinity
      assert Numeric.multiply(RDF.double(-3.14), @positive_infinity) == @negative_infinity

      assert Numeric.multiply(@negative_infinity, RDF.double(3.14))  == @negative_infinity
      assert Numeric.multiply(RDF.double(3.14), @negative_infinity)  == @negative_infinity
      assert Numeric.multiply(@negative_infinity, RDF.double(-3.14)) == @positive_infinity
      assert Numeric.multiply(RDF.double(-3.14), @negative_infinity) == @positive_infinity
    end

    # The following are assertions are not part of the spec.

    test "if both operands are INF, INF is returned" do
      assert Numeric.multiply(@positive_infinity, @positive_infinity) == @positive_infinity
    end

    test "if both operands are -INF, -INF is returned" do
      assert Numeric.multiply(@negative_infinity, @negative_infinity) == @negative_infinity
    end

    test "if one of the operands is INF and the other is -INF, NaN is returned" do
      assert Numeric.multiply(@positive_infinity, @negative_infinity) == RDF.double(:nan)
      assert Numeric.multiply(@negative_infinity, @positive_infinity) == RDF.double(:nan)
    end

    test "coercion" do
      assert Numeric.multiply(1, 2)   == RDF.integer(2)
      assert Numeric.multiply(2, 1.5) == RDF.double(3.0)
      assert RDF.decimal(1.5) |> Numeric.multiply(2) == RDF.decimal(3.0)
      assert Numeric.multiply(2, RDF.decimal(1.5))   == RDF.decimal(3.0)
    end
  end


  describe "divide/2" do
    test "xsd:integer literal / xsd:integer literal" do
      assert Numeric.divide(RDF.integer(4), RDF.integer(2)) == RDF.decimal(2.0)
    end

    test "xsd:decimal literal / xsd:integer literal" do
      assert Numeric.divide(RDF.decimal(4), RDF.integer(2)) == RDF.decimal(2.0)
    end

    test "xsd:double literal / xsd:integer literal" do
      result   = Numeric.divide(RDF.double(4), RDF.integer(2))
      expected = RDF.double(2)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "xsd:decimal literal / xsd:double literal" do
      result   = Numeric.divide(RDF.decimal(4), RDF.double(2))
      expected = RDF.double(2)
      assert result.datatype == expected.datatype
      assert_in_delta result.value, expected.value, 0.000000000000001
    end

    test "a positive number divided by positive zero returns INF" do
      assert Numeric.divide(RDF.double(1.0),  RDF.double(0.0))  == @positive_infinity
      assert Numeric.divide(RDF.double(1.0),  RDF.decimal(0.0)) == @positive_infinity
      assert Numeric.divide(RDF.double(1.0),  RDF.integer(0))   == @positive_infinity
      assert Numeric.divide(RDF.decimal(1.0), RDF.double(0.0))  == @positive_infinity
      assert Numeric.divide(RDF.integer(1),   RDF.double(0.0))  == @positive_infinity
    end

    test "a negative number divided by positive zero returns -INF" do
      assert Numeric.divide(RDF.double(-1.0),  RDF.double(0.0))  == @negative_infinity
      assert Numeric.divide(RDF.double(-1.0),  RDF.decimal(0.0)) == @negative_infinity
      assert Numeric.divide(RDF.double(-1.0),  RDF.integer(0))   == @negative_infinity
      assert Numeric.divide(RDF.decimal(-1.0), RDF.double(0.0))  == @negative_infinity
      assert Numeric.divide(RDF.integer(-1),   RDF.double(0.0))  == @negative_infinity
    end

    test "a positive number divided by negative zero returns -INF" do
      assert Numeric.divide(RDF.double(1.0),  RDF.double("-0.0"))  == @negative_infinity
      assert Numeric.divide(RDF.double(1.0),  RDF.decimal("-0.0")) == @negative_infinity
      assert Numeric.divide(RDF.decimal(1.0), RDF.double("-0.0"))  == @negative_infinity
      assert Numeric.divide(RDF.integer(1),   RDF.double("-0.0"))  == @negative_infinity
    end

    test "a negative number divided by negative zero returns INF" do
      assert Numeric.divide(RDF.double(-1.0),  RDF.double("-0.0"))  == @positive_infinity
      assert Numeric.divide(RDF.double(-1.0),  RDF.decimal("-0.0")) == @positive_infinity
      assert Numeric.divide(RDF.decimal(-1.0), RDF.double("-0.0"))  == @positive_infinity
      assert Numeric.divide(RDF.integer(-1),   RDF.double("-0.0"))  == @positive_infinity
    end

    test "nil is returned for xs:decimal and xs:integer operands, if the divisor is (positive or negative) zero" do
      assert Numeric.divide(RDF.decimal(1.0),  RDF.decimal(0.0)) == nil
      assert Numeric.divide(RDF.decimal(1.0),  RDF.integer(0))   == nil
      assert Numeric.divide(RDF.decimal(-1.0), RDF.decimal(0.0)) == nil
      assert Numeric.divide(RDF.decimal(-1.0), RDF.integer(0))   == nil
      assert Numeric.divide(RDF.integer(1),    RDF.integer(0))   == nil
      assert Numeric.divide(RDF.integer(1),    RDF.decimal(0.0)) == nil
      assert Numeric.divide(RDF.integer(-1),   RDF.integer(0))   == nil
      assert Numeric.divide(RDF.integer(-1),   RDF.decimal(0.0)) == nil
    end

    test "positive or negative zero divided by positive or negative zero returns NaN" do
      assert Numeric.divide(RDF.double( "-0.0"), RDF.double(0.0))  == @nan
      assert Numeric.divide(RDF.double( "-0.0"), RDF.decimal(0.0)) == @nan
      assert Numeric.divide(RDF.double( "-0.0"), RDF.integer(0))   == @nan
      assert Numeric.divide(RDF.decimal("-0.0"), RDF.double(0.0))   == @nan
      assert Numeric.divide(RDF.integer("-0"),   RDF.double(0.0))   == @nan

      assert Numeric.divide(RDF.double( "0.0"),  RDF.double(0.0))  == @nan
      assert Numeric.divide(RDF.double( "0.0"),  RDF.decimal(0.0)) == @nan
      assert Numeric.divide(RDF.double( "0.0"),  RDF.integer(0))   == @nan
      assert Numeric.divide(RDF.decimal("0.0"),  RDF.double(0.0))   == @nan
      assert Numeric.divide(RDF.integer("0"),    RDF.double(0.0))   == @nan

      assert Numeric.divide(RDF.double(0.0) , RDF.double( "-0.0"))  == @nan
      assert Numeric.divide(RDF.decimal(0.0), RDF.double( "-0.0")) == @nan
      assert Numeric.divide(RDF.integer(0)  , RDF.double( "-0.0"))   == @nan
      assert Numeric.divide(RDF.double(0.0) , RDF.decimal("-0.0"))   == @nan
      assert Numeric.divide(RDF.double(0.0) , RDF.integer("-0"))   == @nan

      assert Numeric.divide(RDF.double(0.0) , RDF.double( "0.0"))  == @nan
      assert Numeric.divide(RDF.decimal(0.0), RDF.double( "0.0")) == @nan
      assert Numeric.divide(RDF.integer(0)  , RDF.double( "0.0"))   == @nan
      assert Numeric.divide(RDF.double(0.0) , RDF.decimal("0.0"))   == @nan
      assert Numeric.divide(RDF.double(0.0) , RDF.integer("0"))   == @nan

    end

    test "INF or -INF divided by INF or -INF returns NaN" do
      assert Numeric.divide(@positive_infinity, @positive_infinity) == @nan
      assert Numeric.divide(@negative_infinity, @negative_infinity) == @nan
      assert Numeric.divide(@positive_infinity, @negative_infinity) == @nan
      assert Numeric.divide(@negative_infinity, @positive_infinity) == @nan
    end

    # TODO: What happens when using INF/-INF on division with numbers?

    test "coercion" do
      assert Numeric.divide(4, 2)   == RDF.decimal(2.0)
      assert Numeric.divide(4, 2.0) == RDF.double(2.0)
      assert RDF.decimal(4) |> Numeric.divide(2) == RDF.decimal(2.0)
      assert Numeric.divide(4, RDF.decimal(2.0)) == RDF.decimal(2.0)
      assert Numeric.divide("foo", "bar") == nil
      assert Numeric.divide(4, "bar")     == nil
      assert Numeric.divide("foo", 2)     == nil
      assert Numeric.divide(42, :bar)     == nil
      assert Numeric.divide(:foo, 42)     == nil
      assert Numeric.divide(:foo, :bar)   == nil
    end
  end

  describe "abs/1" do
    test "with xsd:integer" do
      assert RDF.integer(42)  |> Numeric.abs() == RDF.integer(42)
      assert RDF.integer(-42) |> Numeric.abs() == RDF.integer(42)
    end

    test "with xsd:double" do
      assert RDF.double(3.14)   |> Numeric.abs() == RDF.double(3.14)
      assert RDF.double(-3.14)  |> Numeric.abs() == RDF.double(3.14)
      assert RDF.double("INF")  |> Numeric.abs() == RDF.double("INF")
      assert RDF.double("-INF") |> Numeric.abs() == RDF.double("INF")
      assert RDF.double("NAN")  |> Numeric.abs() == RDF.double("NAN")
    end

    test "with xsd:decimal" do
      assert RDF.decimal(3.14)  |> Numeric.abs() == RDF.decimal(3.14)
      assert RDF.decimal(-3.14) |> Numeric.abs() == RDF.decimal(3.14)
    end

    @tag skip: "TODO: derived datatypes"
    test "with derived numerics" do
      assert RDF.literal(-42, datatype: XSD.byte) |> Numeric.abs() ==
             RDF.literal(42, datatype: XSD.byte)
      assert RDF.literal("-42", datatype: XSD.byte) |> Numeric.abs() ==
             RDF.literal(42, datatype: XSD.byte)
      assert RDF.literal(-42, datatype: XSD.nonPositiveInteger)
             |> Numeric.abs() == RDF.integer(42)
    end

    test "with invalid numeric literals" do
      assert RDF.integer("-3.14") |> Numeric.abs() == nil
      assert RDF.double("foo")    |> Numeric.abs() == nil
      assert RDF.decimal("foo")   |> Numeric.abs() == nil
    end

    test "coercion" do
      assert Numeric.abs(42) == RDF.integer(42)
      assert Numeric.abs(-42) == RDF.integer(42)
      assert Numeric.abs(-3.14) == RDF.double(3.14)
      assert Numeric.abs(D.from_float(-3.14)) == RDF.decimal(3.14)
      assert Numeric.abs("foo") == nil
      assert Numeric.abs(:foo) == nil
    end
  end

  describe "round/1" do
    test "with xsd:integer" do
      assert RDF.integer(42)  |> Numeric.round() == RDF.integer(42)
      assert RDF.integer(-42) |> Numeric.round() == RDF.integer(-42)
    end

    test "with xsd:double" do
      assert RDF.double(3.14)  |> Numeric.round() == RDF.double(3.0)
      assert RDF.double(-3.14) |> Numeric.round() == RDF.double(-3.0)
      assert RDF.double(-2.5)  |> Numeric.round() == RDF.double(-2.0)

      assert RDF.double("INF")  |> Numeric.round() == RDF.double("INF")
      assert RDF.double("-INF") |> Numeric.round() == RDF.double("-INF")
      assert RDF.double("NAN")  |> Numeric.round() == RDF.double("NAN")
    end

    test "with xsd:decimal" do
      assert RDF.decimal(2.5)    |> Numeric.round() == RDF.decimal("3")
      assert RDF.decimal(2.4999) |> Numeric.round() == RDF.decimal("2")
      assert RDF.decimal(-2.5)   |> Numeric.round() == RDF.decimal("-2")
    end

    test "with invalid numeric literals" do
      assert RDF.integer("-3.14") |> Numeric.round() == nil
      assert RDF.double("foo")    |> Numeric.round() == nil
      assert RDF.decimal("foo")   |> Numeric.round() == nil
    end

    test "coercion" do
      assert Numeric.round(-42) == RDF.integer(-42)
      assert Numeric.round(-3.14) == RDF.double(-3.0)
      assert Numeric.round(D.from_float(3.14)) == RDF.decimal("3")
      assert Numeric.round("foo") == nil
      assert Numeric.round(:foo)  == nil
    end
  end

  describe "round/2" do
    test "with xsd:integer" do
      assert RDF.integer(42)   |> Numeric.round(3) == RDF.integer(42)
      assert RDF.integer(8452) |> Numeric.round(-2) == RDF.integer(8500)
      assert RDF.integer(85)   |> Numeric.round(-1) == RDF.integer(90)
      assert RDF.integer(-85)  |> Numeric.round(-1) == RDF.integer(-80)
    end

    @tag skip: "TODO: xsd:float"
    test "with xsd:float"

    test "with xsd:double" do
      assert RDF.double(3.14)     |> Numeric.round(1) == RDF.double(3.1)
      assert RDF.double(3.1415e0) |> Numeric.round(2) == RDF.double(3.14e0)

      assert RDF.double("INF")  |> Numeric.round(1) == RDF.double("INF")
      assert RDF.double("-INF") |> Numeric.round(2) == RDF.double("-INF")
      assert RDF.double("NAN")  |> Numeric.round(3) == RDF.double("NAN")
    end

    test "with xsd:decimal" do
      assert RDF.decimal(1.125)  |> Numeric.round(2) == RDF.decimal("1.13")
      assert RDF.decimal(2.4999) |> Numeric.round(2) == RDF.decimal("2.50")
      assert RDF.decimal(-2.55)  |> Numeric.round(1) == RDF.decimal("-2.5")
    end

    test "with invalid numeric literals" do
      assert RDF.integer("-3.14") |> Numeric.round(1) == nil
      assert RDF.double("foo")    |> Numeric.round(2) == nil
      assert RDF.decimal("foo")   |> Numeric.round(3) == nil
    end

    test "coercion" do
      assert Numeric.round(-42, 1) == RDF.integer(-42)
      assert Numeric.round(-3.14, 1) == RDF.double(-3.1)
      assert Numeric.round(D.from_float(3.14), 1) == RDF.decimal("3.1")
      assert Numeric.round("foo", 1) == nil
      assert Numeric.round(:foo, 1)  == nil
    end
  end

  describe "ceil/1" do
    test "with xsd:integer" do
      assert RDF.integer(42)  |> Numeric.ceil() == RDF.integer(42)
      assert RDF.integer(-42) |> Numeric.ceil() == RDF.integer(-42)
    end

    test "with xsd:double" do
      assert RDF.double(10.5)  |> Numeric.ceil() == RDF.double("11")
      assert RDF.double(-10.5) |> Numeric.ceil() == RDF.double("-10")

      assert RDF.double("INF")  |> Numeric.ceil() == RDF.double("INF")
      assert RDF.double("-INF") |> Numeric.ceil() == RDF.double("-INF")
      assert RDF.double("NAN")  |> Numeric.ceil() == RDF.double("NAN")
    end

    test "with xsd:decimal" do
      assert RDF.decimal(10.5)  |> Numeric.ceil() == RDF.decimal("11")
      assert RDF.decimal(-10.5) |> Numeric.ceil() == RDF.decimal("-10")
    end

    test "with invalid numeric literals" do
      assert RDF.integer("-3.14") |> Numeric.ceil() == nil
      assert RDF.double("foo")    |> Numeric.ceil() == nil
      assert RDF.decimal("foo")   |> Numeric.ceil() == nil
    end

    test "coercion" do
      assert Numeric.ceil(-42) == RDF.integer(-42)
      assert Numeric.ceil(-3.14) == RDF.double("-3")
      assert Numeric.ceil(D.from_float(3.14)) == RDF.decimal("4")
      assert Numeric.ceil("foo") == nil
      assert Numeric.ceil(:foo)  == nil
    end
  end

  describe "floor/1" do
    test "with xsd:integer" do
      assert RDF.integer(42)  |> Numeric.floor() == RDF.integer(42)
      assert RDF.integer(-42) |> Numeric.floor() == RDF.integer(-42)
    end

    test "with xsd:double" do
      assert RDF.double(10.5)  |> Numeric.floor() == RDF.double("10")
      assert RDF.double(-10.5) |> Numeric.floor() == RDF.double("-11")

      assert RDF.double("INF")  |> Numeric.floor() == RDF.double("INF")
      assert RDF.double("-INF") |> Numeric.floor() == RDF.double("-INF")
      assert RDF.double("NAN")  |> Numeric.floor() == RDF.double("NAN")
    end

    test "with xsd:decimal" do
      assert RDF.decimal(10.5)  |> Numeric.floor() == RDF.decimal("10")
      assert RDF.decimal(-10.5) |> Numeric.floor() == RDF.decimal("-11")
    end

    test "with invalid numeric literals" do
      assert RDF.integer("-3.14") |> Numeric.floor() == nil
      assert RDF.double("foo")    |> Numeric.floor() == nil
      assert RDF.decimal("foo")   |> Numeric.floor() == nil
    end

    test "coercion" do
      assert Numeric.floor(-42) == RDF.integer(-42)
      assert Numeric.floor(-3.14) == RDF.double("-4")
      assert Numeric.floor(D.from_float(3.14)) == RDF.decimal("3")
      assert Numeric.floor("foo") == nil
      assert Numeric.floor(:foo)  == nil
    end
  end

end
