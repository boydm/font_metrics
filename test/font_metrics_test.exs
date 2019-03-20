#
#  Created by Boyd Multerer on 28/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetricsTest do
  use ExUnit.Case
  doctest FontMetrics

  # import IEx

  @bitter "test/metrics/Bitter-Regular.ttf.metrics"
  @bitter_metrics File.read!(@bitter) |> FontMetrics.from_binary!()
  @bitter_signature @bitter_metrics.source.signature

  @roboto "test/metrics/Roboto-Regular.ttf.metrics"
  @roboto_metrics File.read!(@roboto) |> FontMetrics.from_binary!()
  @roboto_signature @roboto_metrics.source.signature

  @hash_type :sha256

  @version "0.1.0"

  # ============================================================================

  test "expected_hash" do
    assert FontMetrics.expected_hash() == @hash_type
  end

  # ============================================================================
  # from_binary( binary )

  test "from_binary decodes bitter into a proper struct" do
    bin = File.read!(@bitter)

    {:ok, %FontMetrics{} = metrics} = FontMetrics.from_binary(bin)
    assert metrics.version == @version

    assert metrics.max_box == {-60, -265, 1125, 935}
    assert metrics.units_per_em == 1000
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning[{66, 65}] == -30

    assert metrics.source.signature_type == @hash_type
    assert metrics.source.signature == @bitter_signature
    assert metrics.source.font_type == :true_type
  end

  test "from_binary decodes roboto into a proper struct" do
    bin = File.read!(@roboto)

    {:ok, %FontMetrics{} = metrics} = FontMetrics.from_binary(bin)
    assert metrics.version == @version

    assert metrics.max_box == {-1509, -555, 2352, 2163}
    assert metrics.units_per_em == 2048
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning == %{}

    assert metrics.source.signature_type == @hash_type
    assert metrics.source.signature == @roboto_signature
    assert metrics.source.font_type == :true_type
  end

  test "from_binary returns error if the data is bad" do
    bin = File.read!(@bitter)
    assert FontMetrics.from_binary("garbage" <> bin) == {:error, :unzip}
  end

  # ============================================================================
  # from_binary!( binary )

  test "from_binary! decodes bitter into a proper struct" do
    bin = File.read!(@bitter)

    %FontMetrics{} = metrics = FontMetrics.from_binary!(bin)
    assert metrics.version == @version

    assert metrics.max_box == {-60, -265, 1125, 935}
    assert metrics.units_per_em == 1000
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning[{66, 65}] == -30

    assert metrics.source.signature_type == @hash_type
    assert metrics.source.signature == @bitter_signature
    assert metrics.source.font_type == :true_type
  end

  test "from_binary! raises if the data is bad" do
    bin = File.read!(@bitter)

    assert_raise ErlangError, fn ->
      FontMetrics.from_binary!("garbage" <> bin)
    end
  end

  # ============================================================================
  # to_binary( binary )

  test "to_binary( binary ) works" do
    assert FontMetrics.to_binary(@bitter_metrics) == File.read(@bitter)
  end

  test "to_binary( binary ) enforces the version" do
    assert_raise FunctionClauseError, fn ->
      FontMetrics.to_binary(%{@bitter_metrics | version: "not supported"})
    end
  end

  test "to_binary!( binary ) works" do
    assert FontMetrics.to_binary!(@bitter_metrics) == File.read!(@bitter)
  end

  # ============================================================================
  # supported?

  test "supported? checks single characters" do
    assert FontMetrics.supported?(32, @roboto_metrics)
    assert FontMetrics.supported?('A', @roboto_metrics)
    assert FontMetrics.supported?("A", @roboto_metrics)
    assert FontMetrics.supported?('A', @bitter_metrics)

    refute FontMetrics.supported?(25324, @roboto_metrics)
    refute FontMetrics.supported?('括', @roboto_metrics)
    refute FontMetrics.supported?("括", @roboto_metrics)
    refute FontMetrics.supported?("括", @bitter_metrics)

    assert FontMetrics.supported?('Ж', @roboto_metrics)
    refute FontMetrics.supported?('Ж', @bitter_metrics)
  end

  test "supported? checks multiple characters" do
    assert FontMetrics.supported?("Multiple Characters.", @roboto_metrics)
    assert FontMetrics.supported?('Multiple Characters.', @roboto_metrics)

    refute FontMetrics.supported?('Multiple Characters 括', @roboto_metrics)
  end

  # ============================================================================
  # points_to_pixels( points )

  test "points_to_pixels does a simple conversion" do
    assert FontMetrics.points_to_pixels(12) == 16.0
  end

  # ============================================================================
  # ascent(pixels, font_metric)

  test "ascent returns the raw value if pixels is nil" do
    assert FontMetrics.ascent(nil, @bitter_metrics) == @bitter_metrics.ascent
  end

  test "ascent returns a scaled value" do
    raw_value = FontMetrics.ascent(nil, @roboto_metrics)
    scale = 22 / (@roboto_metrics.ascent - @roboto_metrics.descent)

    assert FontMetrics.ascent(22, @roboto_metrics) == raw_value * scale
  end

  # ============================================================================
  # descent(pixels, font_metric)

  test "descent returns the raw value if pixels is nil" do
    assert FontMetrics.descent(nil, @roboto_metrics) == @roboto_metrics.descent
  end

  test "descent returns a scaled value" do
    raw_value = FontMetrics.descent(nil, @roboto_metrics)
    scale = 22 / (@roboto_metrics.ascent - @roboto_metrics.descent)

    assert FontMetrics.descent(22, @roboto_metrics) == raw_value * scale
  end

  # ============================================================================
  # max_box(pixels, font_metric)

  test "max_box returns the raw value if pixels is nil" do
    assert FontMetrics.max_box(nil, @roboto_metrics) == @roboto_metrics.max_box
  end

  test "max_box returns a scaled value" do
    {xv_min, yv_min, xv_max, yv_max} = FontMetrics.max_box(nil, @roboto_metrics)

    scale = 22 / (@roboto_metrics.ascent - @roboto_metrics.descent)
    {x_min, y_min, x_max, y_max} = FontMetrics.max_box(22, @roboto_metrics)

    assert x_min == xv_min * scale
    assert y_min == yv_min * scale
    assert x_max == xv_max * scale
    assert y_max == yv_max * scale
  end

  # ============================================================================
  # width( source, pixels, font_metric)

  test "width of an empty string is always 0" do
    assert FontMetrics.width("", nil, @roboto_metrics) == 0
    assert FontMetrics.width("", nil, @bitter_metrics, true) == 0
    assert FontMetrics.width("", 24, @roboto_metrics) == 0
  end

  test "width returns the raw width of the source if pixels is nil" do
    raw_value =
      @roboto_metrics.metrics[97] +
        @roboto_metrics.metrics[98] + @roboto_metrics.metrics[99]

    assert FontMetrics.width("abc", nil, @roboto_metrics) == raw_value
    assert FontMetrics.width('abc', nil, @roboto_metrics) == raw_value
    assert FontMetrics.width(97, nil, @roboto_metrics) == @roboto_metrics.metrics[97]
  end

  test "width returns the scaled width of the source according to pixel height" do
    metrics = @roboto_metrics

    raw_value = metrics.metrics[97] + metrics.metrics[98] + metrics.metrics[99]
    scale = 22 / (metrics.ascent - metrics.descent)

    assert FontMetrics.width("abc", 22, metrics) == raw_value * scale
    assert FontMetrics.width('abc', 22, metrics) == raw_value * scale
    assert FontMetrics.width(97, 22, metrics) == metrics.metrics[97] * scale
  end

  test "width accounts for kerning if the options is set" do
    string = "PANCAKE"
    metrics = @bitter_metrics

    raw_width = FontMetrics.width(string, nil, metrics)
    raw_kerned = FontMetrics.width(string, nil, metrics, true)
    assert raw_kerned < raw_width

    scale = 22 / (metrics.ascent - metrics.descent)
    assert FontMetrics.width(string, 22, metrics) == raw_width * scale
    assert FontMetrics.width(string, 22, metrics, true) == raw_kerned * scale
  end

  test "width the returns the longest line of a multiline string" do
    longest = "the middle part"
    string = "first part\nthe middle part\nlast part"

    assert FontMetrics.width(string, 22, @roboto_metrics) ==
             FontMetrics.width(longest, 22, @roboto_metrics)
  end

  # ============================================================================
  # position_at( source, n, pixels, font_metric)

  test "position_at works with a simple string" do
    string = "PANCAKE breafasts are yummy"
    {w, 0} = FontMetrics.position_at(string, 8, 22, @roboto_metrics)
    assert trunc(w) == 99
    {w, 0} = FontMetrics.position_at(string, 8, 22, @bitter_metrics)
    assert trunc(w) == 103
    {w, 0} = FontMetrics.position_at(string, 8, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 101
  end

  test "position_at works with a multiline string" do
    string = "PANCAKE breafasts\nPANCAKE are yummy"
    {w, 1} = FontMetrics.position_at(string, 25, 22, @roboto_metrics)
    assert trunc(w) == 89
    {w, 1} = FontMetrics.position_at(string, 25, 22, @bitter_metrics)
    assert trunc(w) == 92
    {w, 1} = FontMetrics.position_at(string, 25, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 90
  end

  # ============================================================================
  # shorten( source, max_width, pixels, font_metric, terminator \\ "...")

  test "shorten shortens a string with an ..." do
    string = "This string will be shortened to the requested width"

    assert FontMetrics.shorten(string, 216, 22, @roboto_metrics) ==
             "This string will be short..."
  end

  test "shorten shortens a string with custom terminator" do
    string = "This string will be shortened to the requested width"

    assert FontMetrics.shorten(string, 226, 22, @roboto_metrics, terminator: "___") ==
             "This string will be short___"
  end

  test "shorten returns an empty string if the max is too small for the terminator" do
    string = "This string will be shortened to the requested width"
    assert FontMetrics.shorten(string, 2, 22, @roboto_metrics) == ""
  end

  test "shorten works with lines in a multiline string" do
    string = "This string\nwill be shortened to the requested\nwidth"

    assert FontMetrics.shorten(string, 160, 22, @roboto_metrics) ==
             "This string\nwill be shortened...\nwidth"
  end

  test "shorten shortens a string using kerning" do
    string = "PANCAKE breafasts are yummy"

    assert FontMetrics.shorten(string, 190, 22, @bitter_metrics, kern: true) ==
             "PANCAKE breafasts..."
  end

  # ============================================================================
  # nearest_gap( source, {x,y}, pixels, font_metrics, opts \\ [] )

  test "nearest_gap finds the gap in a simple string" do
    string = "This is a sample string"
    {14, w, 0} = FontMetrics.nearest_gap(string, {120, 0}, 22, @roboto_metrics)
    assert trunc(w) == 121
    {15, w, 0} = FontMetrics.nearest_gap(string, {124, 0}, 22, @roboto_metrics)
    assert trunc(w) == 125
  end

  test "nearest_gap finds the gap in a kerned string" do
    string = "PANCAKE breafasts are yummy"
    {11, w, 0} = FontMetrics.nearest_gap(string, {120, 0}, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 119
    {12, w, 0} = FontMetrics.nearest_gap(string, {126, 0}, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 129
  end

  test "nearest_gap returns the start if negative y" do
    string = "This is a sample string"
    assert FontMetrics.nearest_gap(string, {20, -10}, 22, @roboto_metrics) == {0, 0, 0}
  end

  test "nearest_gap returns the start if negative x" do
    string = "This is a sample string"
    assert FontMetrics.nearest_gap(string, {-20, 0}, 22, @roboto_metrics) == {0, 0, 0}
  end

  test "nearest_gap returns line of a multiline string" do
    string = "This string\nwill be shortened to the requested\nwidth"
    {15, w, 1} = FontMetrics.nearest_gap(string, {120, 24}, 22, @roboto_metrics)
    assert trunc(w) == 121
    {5, w, 2} = FontMetrics.nearest_gap(string, {120, 46}, 22, @roboto_metrics)
    assert trunc(w) == 45
  end

  # ============================================================================
  # wrap( binary, max_width, pixels, font_metrics, opts )

  @long_str "This is a long string that will be wrapped because it is too wide."
  @long_ret "This is a long string that will be wrapped because it is too wide\nIt also deals with returns in the string"

  test "wrap wraps a string" do
    assert FontMetrics.wrap(@long_str, 110, 22, @roboto_metrics) == 
      "This is a lon\ng string that w\nill be wrappe\nd because it is\n too wide."
  end

  test "wrap wraps a string with a return" do
    assert FontMetrics.wrap(@long_ret, 110, 22, @roboto_metrics) == 
      "This is a lon\ng string that w\nill be wrappe\nd because it is\n too wide\nIt also deals \nwith returns in \nthe string"
  end

  test "wrap wraps a string with numeric indent option" do
    assert FontMetrics.wrap(@long_str, 120, 22, @roboto_metrics, indent: 2) == 
      "This is a long \n  string that will \n  be wrapped be\n  cause it is too \n  wide."
  end

  test "wrap wraps a string with string indent option" do
    assert FontMetrics.wrap(@long_str, 120, 22, @roboto_metrics, indent: "_abc_") == 
      "This is a long \n_abc_string that will \n_abc_be wrapped be\n_abc_cause it is too \n_abc_wide."
  end

  test "wrap wraps a string with charlist indent option" do
    assert FontMetrics.wrap(@long_str, 120, 22, @roboto_metrics, indent: '_abc_') == 
      "This is a long \n_abc_string that will \n_abc_be wrapped be\n_abc_cause it is too \n_abc_wide."
  end

end
