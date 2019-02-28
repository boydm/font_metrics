#
#  Created by Boyd Multerer on 28/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetricsTest do
  use ExUnit.Case
  doctest FontMetrics

  import IEx

  @bitter   "test/metrics/bitter.metrics"
  @bitter_signature "HhK_V3WHLydpJjQ25BxFUv8Q_jn7iHzkezCraBo76gg"
  @bitter_metrics   File.read!( @bitter ) |> FontMetrics.from_binary!()


  @roboto   "test/metrics/roboto.metrics"
  @roboto_signature "eehRQEZX2sIQaz0irSVtR4JKmldlRY7bcskQKkWBbZU"
  @roboto_metrics   File.read!( @roboto ) |> FontMetrics.from_binary!()

  @hash_type  :sha256

  @version            "0.1.0"

  #============================================================================

  test "expected_hash" do
    assert FontMetrics.expected_hash() == @hash_type
  end

  #============================================================================
  # from_binary( binary )

  test "from_binary decodes bitter into a proper struct" do
    bin = File.read!( @bitter )

    {:ok, %FontMetrics{} = metrics} = FontMetrics.from_binary( bin )
    assert metrics.version == @version

    assert metrics.max_box == {-60, -265, 1125, 935}
    assert metrics.units_per_em == 1000
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning[{66, 65}] == -30

    assert metrics.source.signature_type == @hash_type
    assert metrics.source.signature == @bitter_signature
    assert metrics.source.font_type == "TrueType"
  end

  test "from_binary decodes roboto into a proper struct" do
    bin = File.read!( @roboto )

    {:ok, %FontMetrics{} = metrics} = FontMetrics.from_binary( bin )
    assert metrics.version == @version

    assert metrics.max_box == {-1509, -555, 2352, 2163}
    assert metrics.units_per_em == 2048
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning == %{}

    assert metrics.source.signature_type == @hash_type
    assert metrics.source.signature == @roboto_signature
    assert metrics.source.font_type == "TrueType"
  end

  test "from_binary returns error if the data is bad" do
    bin = File.read!( @bitter )
    assert FontMetrics.from_binary( "garbage" <> bin ) == {:error, :unzip}
  end

  #============================================================================
  # from_binary!( binary )

  test "from_binary! decodes bitter into a proper struct" do
    bin = File.read!( @bitter )

    %FontMetrics{} = metrics = FontMetrics.from_binary!( bin )
    assert metrics.version == @version

    assert metrics.max_box == {-60, -265, 1125, 935}
    assert metrics.units_per_em == 1000
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning[{66, 65}] == -30

    assert metrics.source.signature_type == @hash_type
    assert metrics.source.signature == @bitter_signature
    assert metrics.source.font_type == "TrueType"
  end

  test "from_binary! raises if the data is bad" do
    bin = File.read!( @bitter )
    assert_raise ErlangError, fn ->
      FontMetrics.from_binary!( "garbage" <> bin )
    end
  end

  #============================================================================
  # to_binary( binary )

  test "to_binary( binary ) works" do
    assert FontMetrics.to_binary( @bitter_metrics ) == File.read(@bitter)
  end
 
  test "to_binary( binary ) enforces the version" do
    assert_raise FunctionClauseError, fn ->
      FontMetrics.to_binary( %{@bitter_metrics | version: "not supported"} )
    end
  end
 
  test "to_binary!( binary ) works" do
    assert FontMetrics.to_binary!( @bitter_metrics ) == File.read!(@bitter)
  end
  
  #============================================================================
  # supported?

  test "supported? checks single characters" do
    assert FontMetrics.supported?( 32, @roboto_metrics )
    assert FontMetrics.supported?( 'A', @roboto_metrics )
    assert FontMetrics.supported?( "A", @roboto_metrics )
    assert FontMetrics.supported?( 'A', @bitter_metrics )

    refute FontMetrics.supported?( 25324, @roboto_metrics )
    refute FontMetrics.supported?( '括', @roboto_metrics )
    refute FontMetrics.supported?( "括", @roboto_metrics )
    refute FontMetrics.supported?( "括", @bitter_metrics )

    assert FontMetrics.supported?( 'Ж', @roboto_metrics )
    refute FontMetrics.supported?( 'Ж', @bitter_metrics )
  end

  test "supported? checks multiple characters" do
    assert FontMetrics.supported?( "Multiple Characters.", @roboto_metrics )
    assert FontMetrics.supported?( 'Multiple Characters.', @roboto_metrics )

    refute FontMetrics.supported?( 'Multiple Characters 括', @roboto_metrics )
  end

  #============================================================================
  # points_to_pixels( points )

  test "points_to_pixels does a simple conversion" do
    assert FontMetrics.points_to_pixels( 12 ) == 16.0
  end

  #============================================================================
  # ascent(pixels, font_metric)

  test "ascent returns the raw value if pixels is nil" do
    assert FontMetrics.ascent( nil, @bitter_metrics ) == @bitter_metrics.ascent
  end

  test "ascent returns a scaled value" do
    raw_value = FontMetrics.ascent( nil, @roboto_metrics)
    scale = 22 / (@roboto_metrics.ascent - @roboto_metrics.descent)

    assert FontMetrics.ascent( 22, @roboto_metrics) == raw_value * scale
  end

  #============================================================================
  # descent(pixels, font_metric)

  test "descent returns the raw value if pixels is nil" do
    assert FontMetrics.descent( nil, @roboto_metrics ) == @roboto_metrics.descent
  end

  test "descent returns a scaled value" do
    raw_value = FontMetrics.descent( nil, @roboto_metrics)
    scale = 22 / (@roboto_metrics.ascent - @roboto_metrics.descent)

    assert FontMetrics.descent( 22, @roboto_metrics) == raw_value * scale
  end

  #============================================================================
  # max_box(pixels, font_metric)

  test "max_box returns the raw value if pixels is nil" do
    assert FontMetrics.max_box( nil, @roboto_metrics ) == @roboto_metrics.max_box
  end

  test "max_box returns a scaled value" do
    {xv_min, yv_min, xv_max, yv_max} = FontMetrics.max_box( nil, @roboto_metrics)

    scale = 22 / (@roboto_metrics.ascent - @roboto_metrics.descent)
    {x_min, y_min, x_max, y_max} = FontMetrics.max_box( 22, @roboto_metrics)

    assert x_min == xv_min * scale
    assert y_min == yv_min * scale
    assert x_max == xv_max * scale
    assert y_max == yv_max * scale
  end


  #============================================================================
  # width( source, pixels, font_metric)

  test "width of an empty string is always 0" do
    assert FontMetrics.width( "", nil, @roboto_metrics) == 0
    assert FontMetrics.width( "", nil, @bitter_metrics, true) == 0
    assert FontMetrics.width( "", 24, @roboto_metrics) == 0
  end

  test "width returns the raw width of the source if pixels is nil" do
    raw_value = @roboto_metrics.metrics[97] + 
      @roboto_metrics.metrics[98] + @roboto_metrics.metrics[99]

    assert FontMetrics.width( "abc", nil, @roboto_metrics) == raw_value
    assert FontMetrics.width( 'abc', nil, @roboto_metrics) == raw_value
    assert FontMetrics.width( 97, nil, @roboto_metrics) == @roboto_metrics.metrics[97]
  end

  test "width returns the scaled width of the source according to pixel height" do
    metrics = @roboto_metrics

    raw_value = metrics.metrics[97] + metrics.metrics[98] + metrics.metrics[99]
    scale = 22 / (metrics.ascent - metrics.descent)

    assert FontMetrics.width( "abc", 22, metrics) == raw_value * scale
    assert FontMetrics.width( 'abc', 22, metrics) == raw_value * scale
    assert FontMetrics.width( 97, 22, metrics) == metrics.metrics[97] * scale
  end

  test "width accounts for kerning if the options is set" do
    string = "PANCAKE"
    metrics = @bitter_metrics

    raw_width = FontMetrics.width( string, nil, metrics )
    raw_kerned = FontMetrics.width( string, nil, metrics, true )
    assert raw_kerned < raw_width

    scale = 22 / (metrics.ascent - metrics.descent)
    assert FontMetrics.width( string, 22, metrics ) == raw_width * scale
    assert FontMetrics.width( string, 22, metrics, true ) == raw_kerned * scale
  end

  test "width the returns the longest line of a multiline string" do
    longest = "the middle part"
    string = "first part\nthe middle part\nlast part"
    assert FontMetrics.width( string, 22, @roboto_metrics ) ==
      FontMetrics.width( longest, 22, @roboto_metrics )
  end


  #============================================================================
  # shorten( source, max_width, pixels, font_metric, terminator \\ "...")

  test "shorten shortens a string with an ..." do
    string = "This string will be shortened to the requested width"
    assert FontMetrics.shorten( string, 216, 22, @roboto_metrics ) == 
      "This string will be short..."
  end

  test "shorten shortens a string with custom terminator" do
    string = "This string will be shortened to the requested width"
    assert FontMetrics.shorten( string, 226, 22, @roboto_metrics, terminator: "___" ) ==
      "This string will be short___"
  end

  test "shorten returns an empty string if the max width is too small for the terminator" do
    string = "This string will be shortened to the requested width"
    assert FontMetrics.shorten( string, 2, 22, @roboto_metrics ) == ""
  end

  test "shorten works with lines in a multiline string" do
    string = "This string\nwill be shortened to the requested\nwidth"
    assert FontMetrics.shorten( string, 100, 22, @roboto_metrics ) ==
      "This string\nwill be shortened...\nwidth"
  end

end





