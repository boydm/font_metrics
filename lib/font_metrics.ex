#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics do
  @moduledoc """
  Provides graphical measurements for strings.

  
  """

  @version            "0.1.0"
  @name               to_string(__MODULE__)

  @signature_type     :sha256
  @signature_name     to_string(@signature_type)

  @point_to_pixel_ratio  4 / 3

  # ===========================================================================
  @derive [{Msgpax.Packer, include_struct_field: true}]
  defstruct version: nil,
  source: nil, direction: nil, smallest_ppem: nil, units_per_em: nil,
  max_box: nil, ascent: nil, descent: nil, metrics: %{}, kerning: %{}

  # ===========================================================================
  defmodule Error do
    @moduledoc false
    defexception message: "", error: nil, data: nil
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
    with {:ok, bin} <- do_unzip( binary ),
    {:ok, map} <- Msgpax.unpack( bin ) do
      intrepret_unpack( map )
    else
      err -> err
    end
  end

  defp do_unzip( binary ) do
    try do
      {:ok, :zlib.unzip( binary )}
    rescue
      _ -> {:error, :unzip}
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
  defp intrepret_unpack(%{"version" => version}) when version != @version do
    {:error, :version, version}
  end
  defp intrepret_unpack(%{"signature_type" => sig}) when sig != @signature_name do
    {:error, :signature_type, sig}
  end
  defp intrepret_unpack(_), do: {:error, :invalid}

  defp intrepret_unpack!(map) do
    case intrepret_unpack(map) do
      {:ok, font_metrics} -> font_metrics
      err -> raise %FontMetrics.Error{message: "Invalid metrics", error: err, data: map}
    end
  end

  #============================================================================
  # validity checks

  #--------------------------------------------------------
  def supported?( codepoint, %FontMetrics{metrics: metrics, version: @version} )
  when is_integer(codepoint) do
    Map.has_key?(metrics, codepoint)
  end

  def supported?( char_list, %FontMetrics{} = metrics ) when is_list(char_list) do
    Enum.all?( char_list, &supported?(&1, metrics) )
  end

  def supported?( string, %FontMetrics{} = metrics ) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> supported?( metrics )
  end

  #============================================================================
  # use

  #--------------------------------------------------------
  def ascent( pixels, font_metrics )
  def ascent( nil, %FontMetrics{ ascent: ascent, version: @version } ), do: ascent
  def ascent(
    pixels,
    %FontMetrics{ ascent: ascent, descent: descent, version: @version }
  ) do
    ascent * (pixels / (ascent - descent))
  end

  #--------------------------------------------------------
  def descent( pixels, font_metrics )
  def descent( nil, %FontMetrics{ descent: descent, version: @version } ), do: descent
  def descent(
    pixels,
    %FontMetrics{ ascent: ascent, descent: descent, version: @version }
  ) do
    descent * (pixels / (ascent - descent))
  end

  #--------------------------------------------------------
  def points_to_pixels( points ) when is_number(points), do: points * @point_to_pixel_ratio

  #--------------------------------------------------------
  def max_box( pixels, font_metrics )
  def max_box( nil, %FontMetrics{ max_box: max_box, version: @version } ), do: max_box
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
  def width( source, pixels, font_metrics, kern \\ false )

  def width( "", _, _, _ ), do: 0
  def width( '', _, _, _ ), do: 0

  def width( source, nil,
    %FontMetrics{
      metrics: cp_metrics, kerning: kerning, version: @version
    },
    kern
  ) do
    do_width( source, 1.0, cp_metrics, kerning, kern )
  end

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

  # yes. kerning. harder.
  defp do_width( codepoints, scale, cp_metrics, kerning, true ) when is_list(codepoints) do
    do_kerned_width( codepoints, scale, cp_metrics, kerning )
  end

  # if the string has multiple lines, return the width of the longest one
  defp do_width( string, scale, cp_metrics, kerning, kern ) when is_bitstring(string) do
    string
    |> String.split( "\n")
    |> Enum.map( &String.to_charlist(&1) )
    |> Enum.reduce( 0, fn(line, max_width) ->
      case do_width( line, scale, cp_metrics, kerning, kern ) do
        width when width > max_width -> width
        _ -> max_width
      end
    end)
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

  #--------------------------------------------------------


import IEx
  def shorten( source, max_width, pixels, font_metrics, opts \\ [] )

  def shorten(
    source, max_width, pixels,
    %FontMetrics{
      metrics: cp_metrics, ascent: ascent, descent: descent,
      kerning: kerning, version: @version
    } = font_metrics,
    opts
  ) when is_list(source) and is_list(opts) do
    kern = !!opts[:kern]
    terminator = case opts[:terminator] do
      nil -> '...'
      t when is_list(t) -> t
      t when is_bitstring(t) -> String.to_charlist(t)
    end

    # calculate the scale to use
    scale = case pixels do
      nil -> 1.0
      p -> p / (ascent - descent)
    end

    # terminator_width = do_width( terminator, scale, font_metrics, kern )
    terminator_width = do_width( terminator, scale, cp_metrics, kerning, kern )
    do_shorten(
      source,
      max_width - terminator_width,
      scale, font_metrics, kern
    )
    |> case do
      '' -> ''
      out -> (terminator ++ out) |> Enum.reverse()
    end
  end

  def shorten( source, width, max_pixels, %FontMetrics{} = font_metrics, opts )
  when is_bitstring(source) do
    source
    |> String.split( "\n")
    |> Enum.map( &String.to_charlist(&1) )
    |> Enum.map( &shorten( &1, width, max_pixels, font_metrics, opts ) )
    |> Enum.map( &to_string(&1) )
    |> Enum.join( "\n" )
  end

  def do_shorten( _, max_width, _, _, _ ) when max_width <= 0, do: ''

  # various ways to structure the code. This attempts to reuse calculates and
  # and keep it to a single pass as much as possible
  def do_shorten(
    source, max_width, scale,
    %FontMetrics{metrics: cp_metrics},
    false
  ) do
    max_width = max_width / scale
    {out,_} = Enum.reduce_while(source, {[],0}, fn(cp, {acc,width})->
      new_width = width + (cp_metrics[cp] || cp_metrics[0])
      cond do
        new_width < max_width -> {:cont, { [cp | acc], new_width}}
        true -> {:halt, {acc,width}}
      end
    end)
    out
  end

end
















