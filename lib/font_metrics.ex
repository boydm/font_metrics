#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics do
  @moduledoc """
  Documentation for FontMetrics.
  """

  import IEx

  @version            "0.1.0"

  @signature_type     :sha256

  @point_to_pixel_ratio  4 / 3

  defstruct version: nil,
  source: nil, direction: nil, smallest_ppem: nil, units_per_em: nil,
  max_box: nil, ascent: nil, descent: nil, metrics: %{}, kerning: %{}

  #============================================================================
  # high-level functions

  #--------------------------------------------------------
  def expected_hash(), do: @signature_type

  #--------------------------------------------------------
  def to_binary( %FontMetrics{} = metrics ) do
    :erlang.term_to_binary(metrics, [{:compressed, 9}, {:minor_version, 2}])
  end

  #--------------------------------------------------------
  def from_binary( binary ) when is_binary(binary) do
    case :erlang.binary_to_term(binary, [:safe]) do
      :badarg -> {:error, :invalid}
      term -> {:ok, term}
    end
  end

  #============================================================================
  # validity checks

  #--------------------------------------------------------
  def is_supported?( codepoint, %FontMetrics{metrics: metrics, version: @version} )
  when is_integer(codepoint) do
    Map.has_key?(metrics, codepoint)
  end

  def is_supported?( char_list, %FontMetrics{} = metrics ) when is_list(char_list) do
    Enum.all?( char_list, &is_supported?(&1, metrics) )
  end

  def is_supported?( string, %FontMetrics{} = metrics ) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> is_supported?( metrics )
  end

  #============================================================================
  # use

  #--------------------------------------------------------
  def ascent( pixels, font_metrics )
  def ascent(
    pixels,
    %FontMetrics{ ascent: ascent, ascent: ascent, descent: descent, version: @version }
  ) do
    ascent * (pixels / (ascent - descent))
  end

  #--------------------------------------------------------
  def points_to_pixels( points ) when is_number(points), do: points * @point_to_pixel_ratio

  #--------------------------------------------------------
  def max_box( pixels, font_metrics )
  def max_box(
    pixels,
    %FontMetrics{
      max_box: {x_min, y_min, x_max, y_max},
      ascent: ascent, descent: descent, version: @version
    }
  ) do
    scale = pixels / (ascent - descent)
    {x_min * scale, y_min * scale, x_max * scale, y_max * scale}
  end

  #--------------------------------------------------------
  def metrics( source, pixels, font_metrics )

  def metrics(
    source, pixels,
    %FontMetrics{metrics: cp_metrics, ascent: ascent, descent: descent, version: @version}
  ) when is_number(pixels) and pixels > 0 do
    scale = pixels / (ascent - descent)
    do_metrics( source, scale, cp_metrics )
  end

  defp do_metrics( codepoint, scale, cp_metrics ) when is_integer(codepoint) do
    case cp_metrics[codepoint] do
      nil -> {:error, :not_found}
      adv -> adv * scale
    end
  end

  defp do_metrics( codepoints, scale, cp_metrics ) when is_list(codepoints) do
    Enum.map(codepoints, &do_metrics(&1, scale, cp_metrics) )
  end

  defp do_metrics( string, scale, cp_metrics ) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> do_metrics( scale, cp_metrics )
  end

  #--------------------------------------------------------
  def width( source, pixels, font_metrics, kern \\ false )

  def width(
    source, pixels,
    %FontMetrics{
      metrics: cp_metrics, ascent: ascent, descent: descent,
      kerning: kerning, version: @version
    },
    kern
  ) when is_number(pixels) and pixels > 0 do
    scale = pixels / (ascent - descent)
    do_width( source, scale, cp_metrics, kerning, kern )
  end

  defp do_width( codepoint, scale, cp_metrics, _, _ ) when is_integer(codepoint) do
    # if the codepoint isn't supported by the font, use 0 - missing character tofu
    (cp_metrics[codepoint] || cp_metrics[0]) * scale
  end

  # no kerning. easy.
  defp do_width( codepoints, scale, cp_metrics, _, false ) when is_list(codepoints) do
    Enum.reduce( codepoints, 0, fn(codepoint, width) ->
      # if the codepoint isn't supported by the font, use 0 - missing character tofu
      width + (cp_metrics[codepoint] || cp_metrics[0])
    end) * scale
  end

  # yes kerning. harder.
  defp do_width( codepoints, scale, cp_metrics, kerning, true ) when is_list(codepoints) do
    do_kerned_width( codepoints, scale, cp_metrics, kerning )
  end

  defp do_width( string, scale, cp_metrics, kerning, kern ) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> do_width( scale, cp_metrics, kerning, kern )
  end

  defp do_kerned_width( codepoints, scale, cp_metrics, kerning, width \\ 0 )
  defp do_kerned_width( [], scale, _, _, width ), do: width * scale
  defp do_kerned_width( [last_cp], scale, cp_metrics, _, width ) do
    adv = cp_metrics[last_cp] || cp_metrics[0]
    (width + adv) * scale
  end
  defp do_kerned_width( [cp | codepoints], scale, cp_metrics, kerning, width ) do
    [next_cp | _] = codepoints
    kern_amount =  Map.get( kerning, {cp, next_cp}, 0 )
    width = width + (cp_metrics[cp] || cp_metrics[0]) + kern_amount
    do_kerned_width( codepoints, scale, cp_metrics, kerning, width )
  end

end






