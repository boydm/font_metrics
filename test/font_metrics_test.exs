#
#  Created by Boyd Multerer on 28/02/19.
#  Copyright © 2019-2021 Kry10 Industries. All rights reserved.
#

defmodule FontMetricsTest do
  use ExUnit.Case
  doctest FontMetrics

  # import IEx

  @bitter_metrics "test/metrics/bitter.ttf.metrics_term"
                  |> File.read!()
                  |> :erlang.binary_to_term()

  @roboto_metrics "test/metrics/roboto.ttf.metrics_term"
                  |> File.read!()
                  |> :erlang.binary_to_term()

  @version "0.1.1"
  @hash_type :sha256

  # ============================================================================

  test "version" do
    assert FontMetrics.version() == @version
  end

  test "expected_hash" do
    assert FontMetrics.expected_hash() == @hash_type
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
    scale = 22 / @roboto_metrics.units_per_em

    assert FontMetrics.ascent(22, @roboto_metrics) == raw_value * scale
  end

  # ============================================================================
  # descent(pixels, font_metric)

  test "descent returns the raw value if pixels is nil" do
    assert FontMetrics.descent(nil, @roboto_metrics) == @roboto_metrics.descent
  end

  test "descent returns a scaled value" do
    raw_value = FontMetrics.descent(nil, @roboto_metrics)
    scale = 22 / @roboto_metrics.units_per_em

    assert FontMetrics.descent(22, @roboto_metrics) == raw_value * scale
  end

  # ============================================================================
  # max_box(pixels, font_metric)

  test "max_box returns the raw value if pixels is nil" do
    assert FontMetrics.max_box(nil, @roboto_metrics) == @roboto_metrics.max_box
  end

  test "max_box returns a scaled value" do
    {xv_min, yv_min, xv_max, yv_max} = FontMetrics.max_box(nil, @roboto_metrics)

    scale = 22 / @roboto_metrics.units_per_em
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
    assert FontMetrics.width("", nil, @bitter_metrics, kern: true) == 0
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
    scale = 22 / metrics.units_per_em

    assert FontMetrics.width("abc", 22, metrics) == raw_value * scale
    assert FontMetrics.width('abc', 22, metrics) == raw_value * scale
    assert FontMetrics.width(97, 22, metrics) == metrics.metrics[97] * scale
  end

  test "width accounts for kerning if the options is set" do
    string = "PANCAKE"
    metrics = @bitter_metrics

    raw_width = FontMetrics.width(string, nil, metrics)
    raw_kerned = FontMetrics.width(string, nil, metrics, kern: true)
    assert raw_kerned < raw_width

    scale = 22 / metrics.units_per_em
    assert FontMetrics.width(string, 22, metrics) == raw_width * scale
    assert FontMetrics.width(string, 22, metrics, kern: true) == raw_kerned * scale
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
    assert trunc(w) == 104
    {w, 0} = FontMetrics.position_at(string, 8, 22, @bitter_metrics)
    assert trunc(w) == 110
    {w, 0} = FontMetrics.position_at(string, 8, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 108
  end

  test "position_at returns zero length at position 0" do
    string = "PANCAKE breafasts are yummy"
    {w, 0} = FontMetrics.position_at(string, 0, 22, @roboto_metrics)
    assert w == 0
  end

  test "with just one character, different positions in the string are multiples of the same width" do
    string = "AAAAAAAAAA" # 10 chars long
    {w, 0} = FontMetrics.position_at(string, 1, 22, @roboto_metrics)
    {five_w, 0} = FontMetrics.position_at(string, 5, 22, @roboto_metrics)
    assert 5*w == five_w
    {ten_w, 0} = FontMetrics.position_at(string, 10, 22, @roboto_metrics)
    assert 2*five_w == ten_w
  end

  test "the length of an empty string is zero" do
    {w1, 0} = FontMetrics.position_at("", 0, 22, @roboto_metrics)
    {w2, 0} = FontMetrics.position_at("", 1, 22, @roboto_metrics)
    assert w1 == 0
    assert w1 == w2
  end

  test "position one returns the same length as a one-character long string" do
    {w1, 0} = FontMetrics.position_at("a", 1, 22, @roboto_metrics)
    {w2, 0} = FontMetrics.position_at("aaaa", 1, 22, @roboto_metrics)
    assert w1 == w2
  end

  test "position_at works with a multiline string" do
    string = "PANCAKE breafasts\nPANCAKE are yummy"
    {w, 1} = FontMetrics.position_at(string, 25, 22, @roboto_metrics)
    assert trunc(w) == 98
    {w, 1} = FontMetrics.position_at(string, 25, 22, @bitter_metrics)
    assert trunc(w) == 105
    {w, 1} = FontMetrics.position_at(string, 25, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 103
  end

  # ============================================================================
  # shorten( source, max_width, pixels, font_metric, terminator \\ "...")

  test "shorten shortens a string with an ..." do
    string = "This string will be shortened to the requested width"

    assert FontMetrics.shorten(string, 216, 22, @roboto_metrics) ==
             "This string will be sh…"
  end

  test "shorten shortens a string with custom terminator" do
    string = "This string will be shortened to the requested width"

    assert FontMetrics.shorten(string, 226, 22, @roboto_metrics, terminator: "___") ==
             "This string will be s___"
  end

  test "shorten returns an empty string if the max is too small for the terminator" do
    string = "This string will be shortened to the requested width"
    assert FontMetrics.shorten(string, 2, 22, @roboto_metrics) == ""
  end

  test "shorten works with lines in a multiline string" do
    string = "This string\nwill be shortened to the requested\nwidth"

    assert FontMetrics.shorten(string, 160, 22, @roboto_metrics) ==
             "This string\nwill be shorten…\nwidth"
  end

  test "shorten shortens a string using kerning" do
    string = "PANCAKE breafasts are yummy"

    assert FontMetrics.shorten(string, 190, 22, @bitter_metrics, kern: true) ==
             "PANCAKE breaf…"
  end

  # ============================================================================
  # nearest_gap( source, {x,y}, pixels, font_metrics, opts \\ [] )

  test "nearest_gap finds the gap in a simple string" do
    string = "This is a sample string"
    {13, w, 0} = FontMetrics.nearest_gap(string, {120, 0}, 22, @roboto_metrics)
    assert trunc(w) == 129
    {14, w, 0} = FontMetrics.nearest_gap(string, {136, 0}, 22, @roboto_metrics)
    assert trunc(w) == 141
  end

  test "nearest_gap finds the gap in a kerned string" do
    string = "PANCAKE breafasts are yummy"
    {9, w, 0} = FontMetrics.nearest_gap(string, {120, 0}, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 121
    {10, w, 0} = FontMetrics.nearest_gap(string, {136, 0}, 22, @bitter_metrics, kern: true)
    assert trunc(w) == 131
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
    {13, w, 1} = FontMetrics.nearest_gap(string, {120, 24}, 22, @roboto_metrics)
    assert trunc(w) == 118
    {5, w, 2} = FontMetrics.nearest_gap(string, {120, 46}, 22, @roboto_metrics)
    assert trunc(w) == 53
  end

  # ============================================================================
  # wrap( binary, max_width, pixels, font_metrics, opts )

  @long_str "This is a long string that will be wrapped because it is too wide."
  @long_ret "This is a long string that will be wrapped because it is too wide\nIt also deals with returns in the string"

  test "wrap wraps a string - at word boundaries by default" do
    assert FontMetrics.wrap(@long_str, 110, 22, @roboto_metrics) ==
             "This is a\nlong string\nthat will be\nwrapped\nbecause it\nis too\nwide."
  end

  test "wrap wraps a string with a return - at word boundaries by default" do
    assert FontMetrics.wrap(@long_ret, 110, 22, @roboto_metrics) ==
             "This is a\nlong string\nthat will be\nwrapped\nbecause it\nis too wide\nIt also\ndeals with\nreturns in\nthe string"
  end

  test "wrap wraps a string - at word boundaries" do
    assert FontMetrics.wrap(@long_str, 110, 22, @roboto_metrics, wrap: :word) ==
             "This is a\nlong string\nthat will be\nwrapped\nbecause it\nis too\nwide."
  end

  test "wrap wraps a string with a return - at word boundaries" do
    assert FontMetrics.wrap(@long_ret, 110, 22, @roboto_metrics, wrap: :word) ==
             "This is a\nlong string\nthat will be\nwrapped\nbecause it\nis too wide\nIt also\ndeals with\nreturns in\nthe string"
  end

  test "wrap wraps a string - at character boundaries" do
    assert FontMetrics.wrap(@long_str, 110, 22, @roboto_metrics, wrap: :char) ==
             "This is a lo\nng string t\nhat will be \nwrapped b\necause it i\ns too wide."
  end

  test "wrap wraps a string with a return - at character boundaries" do
    assert FontMetrics.wrap(@long_ret, 110, 22, @roboto_metrics, wrap: :char) ==
             "This is a lo\nng string t\nhat will be \nwrapped b\necause it i\ns too wide\nIt also deal\ns with retur\nns in the st\nring"
  end
end
