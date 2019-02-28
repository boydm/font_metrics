#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics do
  @moduledoc """
  Provides graphical measurements for strings.

  
  """

  import IEx

  @version            "0.1.0"
  @name               to_string(__MODULE__)

  @signature_type     :sha256
  @signature_name     to_string(@signature_type)

  @point_to_pixel_ratio  4 / 3

  # ===========================================================================
  @derive [{Msgpax.Packer, include_struct_field: true}]
  @derive Msgpax.Packer
  defstruct version: nil,
  source: nil, direction: nil, smallest_ppem: nil, units_per_em: nil,
  max_box: nil, ascent: nil, descent: nil, metrics: %{}, kerning: %{}

  # ===========================================================================
  defmodule Error do
    @moduledoc false
    defexception error: nil, data: nil
  end


  #============================================================================
  # high-level functions

  #--------------------------------------------------------
  def expected_hash(), do: @signature_type

  #--------------------------------------------------------
  def to_binary(
    %{version: @version} = metrics
  ) do
    metrics
    |> prep_bin()
    |> Msgpax.pack()
    |> case do
      {:ok, io_list} -> {:ok, :zlib.zip( io_list )}
      err -> err
    end
  end

  #--------------------------------------------------------
  def to_binary!(
    %{version: @version} = metrics
  ) do
    metrics
    |> prep_bin()
    |> Msgpax.pack!()
    |> :zlib.zip()
  end

  defp prep_bin( %{max_box: {x_min,y_min,x_max,y_max}, kerning: kerning} = metrics ) do
    metrics
    |> Map.put( :max_box, [x_min, y_min, x_max, y_max] )
    |> Map.put( :kerning, Enum.map(kerning, fn({{a,b},v})-> [a,b,v] end) )
  end

  #--------------------------------------------------------
  def from_binary( binary ) when is_binary(binary) do
    :zlib.unzip( binary )
    |> Msgpax.unpack()
    |> case do
      {:ok, map} -> intrepret_unpack(map)
      err -> err
    end
  end

  #--------------------------------------------------------
  def from_binary!( binary ) when is_binary(binary) do
    :zlib.unzip( binary )
    |> Msgpax.unpack!()
    |> intrepret_unpack!()
  end

  #------------------------------------
  defp intrepret_unpack(%{
    "__struct__" => @name,
    "version" => @version,
    "direction" => direction,
    "ascent" => ascent,
    "descent" => descent,
    "smallest_ppem" => smallest_ppem,
    "units_per_em" => units_per_em,
    "max_box" => [x_min, y_min, x_max, y_max],
    "kerning" => kerning,
    "metrics" => metrics,
    "source" => %{
      "created_at" => created_at,
      "modified_at" => modified_at, 
      "font_type" => font_type,
      "signature" => signature,
      "signature_type" => @signature_name
    }
  }) do
    {:ok, %FontMetrics{
      version: @version,
      direction: direction,
      ascent: ascent,
      descent: descent,
      smallest_ppem: smallest_ppem,
      units_per_em: units_per_em,
      max_box: {x_min, y_min, x_max, y_max},
      kerning: Enum.map(kerning, fn([a,b,v]) -> {{a,b},v} end) |> Enum.into(%{}),
      metrics: metrics,
      source: %FontMetrics.Source{
        created_at: created_at,
        modified_at: modified_at,          
        font_type: font_type,
        signature: signature,
        signature_type: :sha256,
      },
    }}
  end
  defp intrepret_unpack(%{"version" => version}) when version != version do
    {:error, :version, version}
  end
  defp intrepret_unpack(%{"signature_type" => sig}) when sig != @signature_name do
    {:error, :signature_type, sig}
  end
  defp intrepret_unpack(_), do: {:error, :invalid}

  defp intrepret_unpack!(map) do
    case intrepret_unpack(map) do
      {:ok, font_metrics} -> font_metrics
      err -> raise %FontMetrics.Error{error: err, data: map}
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






