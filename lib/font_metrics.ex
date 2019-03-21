#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics do
  @moduledoc """
  FontMetrics works with pre-generated font metrics to explore and calculate various
  measurements of text in a given font and size.

  For example, if you want to know how wide or tall a string of text will be when
  it is rendered in a given font at a given size, then this can help you out.

  This library is intended to be used with the [Scenic](https://hex.pm/packages/scenic)
  framework, but doesn't depend on it, so it is usable elsewhere.

  ## Installation

  If [available in Hex](https://hex.pm/docs/publish), the package can be installed
  by adding `font_metrics` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:font_metrics, "~> 0.3"}
    ]
  end
  ```

  ## Generating Metrics

  You will need to use another package to compile the font metrics data from a font.

  This can be done with the truetype_metrics package. Look for it on hex...
  """

  # This represents the version of the data format, not the hex package.
  # Hopefully, it doesn't change much if at all...
  @version "0.1.0"
  @name to_string(__MODULE__)

  @signature_type :sha256
  @signature_name to_string(@signature_type)

  @point_to_pixel_ratio 4 / 3

  # import IEx

  # ===========================================================================
  @derive [{Msgpax.Packer, include_struct_field: true}]
  defstruct version: nil,
            source: nil,
            direction: nil,
            smallest_ppem: nil,
            units_per_em: nil,
            max_box: nil,
            ascent: nil,
            descent: nil,
            metrics: %{},
            kerning: %{}

  # ===========================================================================
  defmodule Error do
    @moduledoc false
    defexception message: "", error: nil, data: nil
  end

  # ============================================================================
  # high-level functions

  # --------------------------------------------------------
  @doc """
  The type of hash used to verify the signature

  This should return `:sha256`
  """
  def expected_hash(), do: @signature_type

  # --------------------------------------------------------
  @doc """
  Serialize a `%FontMetrics{}` struct to a binary.

  returns `{:ok, binary}`
  """
  def to_binary(%{version: @version} = metrics) do
    metrics
    |> prep_bin()
    |> Msgpax.pack()
    |> case do
      {:ok, io_list} -> {:ok, :zlib.zip(io_list)}
      err -> err
    end
  end

  # --------------------------------------------------------
  @doc """
  Serialize a `%FontMetrics{}` struct to a binary.

  returns `binary`
  """
  def to_binary!(%{version: @version} = metrics) do
    metrics
    |> prep_bin()
    |> Msgpax.pack!()
    |> :zlib.zip()
  end

  defp prep_bin(
         %{
           max_box: {x_min, y_min, x_max, y_max},
           kerning: kerning,
           source: %{font_type: font_type} = source
         } = metrics
       ) do
    font_type =
      case font_type do
        :true_type -> "TrueType"
      end

    source = Map.put(source, :font_type, font_type)

    metrics
    |> Map.put(:max_box, [x_min, y_min, x_max, y_max])
    |> Map.put(:kerning, Enum.map(kerning, fn {{a, b}, v} -> [a, b, v] end))
    |> Map.put(:source, source)
  end

  # --------------------------------------------------------
  @doc """
  Deserialize a binary into a `%FontMetrics{}`.

  returns `{:ok, font_metric}`
  """
  def from_binary(binary) when is_binary(binary) do
    with {:ok, bin} <- do_unzip(binary),
         {:ok, map} <- Msgpax.unpack(bin) do
      intrepret_unpack(map)
    else
      err -> err
    end
  end

  defp do_unzip(binary) do
    try do
      {:ok, :zlib.unzip(binary)}
    rescue
      _ -> {:error, :unzip}
    end
  end

  # --------------------------------------------------------
  @doc """
  Deserialize a binary into a `%FontMetrics{}`.

  returns `font_metric`
  """
  def from_binary!(binary) when is_binary(binary) do
    :zlib.unzip(binary)
    |> Msgpax.unpack!()
    |> intrepret_unpack!()
  end

  # ------------------------------------
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
           "signature_type" => @signature_name,
           "file" => file
         }
       }) do
    font_type =
      case font_type do
        "TrueType" -> :true_type
      end

    {:ok,
     %FontMetrics{
       version: @version,
       direction: direction,
       ascent: ascent,
       descent: descent,
       smallest_ppem: smallest_ppem,
       units_per_em: units_per_em,
       max_box: {x_min, y_min, x_max, y_max},
       kerning: Enum.map(kerning, fn [a, b, v] -> {{a, b}, v} end) |> Enum.into(%{}),
       metrics: metrics,
       source: %FontMetrics.Source{
         created_at: created_at,
         modified_at: modified_at,
         font_type: font_type,
         signature: signature,
         signature_type: :sha256,
         file: file
       }
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

  # ============================================================================
  # validity checks

  # --------------------------------------------------------
  @doc """
  Checks if all the characters can be rendered by the font

  returns `true` or `false`
  """

  def supported?(codepoint, %FontMetrics{metrics: metrics, version: @version})
      when is_integer(codepoint) do
    Map.has_key?(metrics, codepoint)
  end

  def supported?(char_list, %FontMetrics{} = metrics) when is_list(char_list) do
    Enum.all?(char_list, &supported?(&1, metrics))
  end

  def supported?(string, %FontMetrics{} = metrics) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> supported?(metrics)
  end

  # ============================================================================
  # use

  # --------------------------------------------------------
  @doc """
  Get the ascent of the font scaled to the pixel height

  returns `ascent`
  """
  def ascent(pixels, font_metrics)
  def ascent(nil, %FontMetrics{ascent: ascent, version: @version}), do: ascent

  def ascent(
        pixels,
        %FontMetrics{ascent: ascent, descent: descent, version: @version}
      ) do
    ascent * (pixels / (ascent - descent))
  end

  # --------------------------------------------------------
  @doc """
  Get the descent of the font scaled to the pixel height

  returns `descent`
  """
  def descent(pixels, font_metrics)
  def descent(nil, %FontMetrics{descent: descent, version: @version}), do: descent

  def descent(
        pixels,
        %FontMetrics{ascent: ascent, descent: descent, version: @version}
      ) do
    descent * (pixels / (ascent - descent))
  end

  # --------------------------------------------------------
  @doc """
  Transform point values into pixels

  returns `pixels`
  """
  def points_to_pixels(points) when is_number(points), do: points * @point_to_pixel_ratio

  # --------------------------------------------------------
  @doc """
  Return a box that would hold the largest character in the font.

  The response is scaled to the pixel size.

  returns `{x_min, y_min, x_max, y_max}`
  """
  def max_box(pixels, font_metrics)
  def max_box(nil, %FontMetrics{max_box: max_box, version: @version}), do: max_box

  def max_box(
        pixels,
        %FontMetrics{
          max_box: {x_min, y_min, x_max, y_max},
          ascent: ascent,
          descent: descent,
          version: @version
        }
      ) do
    scale = pixels / (ascent - descent)
    {x_min * scale, y_min * scale, x_max * scale, y_max * scale}
  end

  # --------------------------------------------------------
  @doc """
  Measure the width of a string, scaled to a pixel size

  returns `width`
  """
  def width(source, pixels, font_metrics, kern \\ false)

  def width("", _, _, _), do: 0
  def width('', _, _, _), do: 0

  def width(
        source,
        nil,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning,
          version: @version
        },
        kern
      ) do
    do_width(source, 1.0, cp_metrics, kerning, kern)
  end

  def width(
        source,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          ascent: ascent,
          descent: descent,
          kerning: kerning,
          version: @version
        },
        kern
      )
      when is_number(pixels) and pixels > 0 do
    scale = pixels / (ascent - descent)
    do_width(source, scale, cp_metrics, kerning, kern)
  end

  defp do_width(codepoint, scale, cp_metrics, _, _) when is_integer(codepoint) do
    # if the codepoint isn't supported by the font, use 0 - missing character tofu
    (cp_metrics[codepoint] || cp_metrics[0]) * scale
  end

  # no kerning. easy.
  defp do_width(codepoints, scale, cp_metrics, _, false) when is_list(codepoints) do
    Enum.reduce(codepoints, 0, fn codepoint, width ->
      # if the codepoint isn't supported by the font, use 0 - missing character tofu
      width + (cp_metrics[codepoint] || cp_metrics[0])
    end) * scale
  end

  # yes. kerning. harder.
  defp do_width(codepoints, scale, cp_metrics, kerning, true) when is_list(codepoints) do
    do_kerned_width(codepoints, scale, cp_metrics, kerning)
  end

  # if the string has multiple lines, return the width of the longest one
  defp do_width(string, scale, cp_metrics, kerning, kern) when is_bitstring(string) do
    string
    |> String.split("\n")
    |> Enum.map(&String.to_charlist(&1))
    |> Enum.reduce(0, fn line, max_width ->
      case do_width(line, scale, cp_metrics, kerning, kern) do
        width when width > max_width -> width
        _ -> max_width
      end
    end)
  end

  defp do_kerned_width(codepoints, scale, cp_metrics, kerning, width \\ 0)
  defp do_kerned_width([], scale, _, _, width), do: width * scale

  defp do_kerned_width([last_cp], scale, cp_metrics, _, width) do
    adv = cp_metrics[last_cp] || cp_metrics[0]
    (width + adv) * scale
  end

  defp do_kerned_width([cp | codepoints], scale, cp_metrics, kerning, width) do
    [next_cp | _] = codepoints
    kern_amount = Map.get(kerning, {cp, next_cp}, 0)
    width = width + (cp_metrics[cp] || cp_metrics[0]) + kern_amount
    do_kerned_width(codepoints, scale, cp_metrics, kerning, width)
  end

  # --------------------------------------------------------
  @doc """
  Shorten a string to fit a given width

  options
  * `:kern` - account for Kerning - true or false
  * `:terminator` - add this string to the end of the shortened string. Defaults to "..."

  returns `string`
  """

  def shorten(source, max_width, pixels, font_metrics, opts \\ [])

  def shorten(
        source,
        max_width,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          ascent: ascent,
          descent: descent,
          kerning: kerning,
          version: @version
        } = font_metrics,
        opts
      )
      when is_list(source) and is_list(opts) do
    kern = !!opts[:kern]

    terminator =
      case opts[:terminator] do
        nil -> '...'
        t when is_list(t) -> t
        t when is_bitstring(t) -> String.to_charlist(t)
      end

    # calculate the scale to use
    scale =
      case pixels do
        nil -> 1.0
        p -> p / (ascent - descent)
      end

    # terminator_width = do_width( terminator, scale, font_metrics, kern )
    terminator_width = do_width(terminator, scale, cp_metrics, kerning, kern)

    do_shorten(
      source,
      max_width - terminator_width,
      scale,
      font_metrics,
      kern
    )
    |> case do
      '' ->
        ''

      out ->
        case Enum.reverse(out) do
          ^source -> source
          out -> out ++ terminator
        end
    end
  end

  def shorten(source, width, max_pixels, %FontMetrics{} = font_metrics, opts)
      when is_bitstring(source) do
    source
    |> String.split("\n")
    |> Enum.map(&String.to_charlist(&1))
    |> Enum.map(&shorten(&1, width, max_pixels, font_metrics, opts))
    |> Enum.map(&to_string(&1))
    |> Enum.join("\n")
  end

  def do_shorten(_, max_width, _, _, _) when max_width <= 0, do: ''

  # various ways to structure the code. This attempts to reuse calculations and
  # and keep it to a single pass as much as possible
  # no kerning
  def do_shorten(
        source,
        max_width,
        scale,
        %FontMetrics{metrics: cp_metrics},
        false
      ) do
    max_width = max_width / scale

    {out, _} =
      Enum.reduce_while(source, {[], 0}, fn cp, {acc, width} ->
        new_width = width + (cp_metrics[cp] || cp_metrics[0])

        cond do
          new_width < max_width -> {:cont, {[cp | acc], new_width}}
          true -> {:halt, {acc, width}}
        end
      end)

    out
  end

  # yes kerning
  def do_shorten(
        source,
        max_width,
        scale,
        %FontMetrics{metrics: cp_metrics, kerning: kerning},
        true
      ) do
    max = max_width / scale
    do_kern_shorten(source, max, cp_metrics, kerning)
  end

  defp do_kern_shorten(codepoints, max, cp_metrics, kerning, k_next \\ 0, width \\ 0, out \\ '')
  defp do_kern_shorten('', _, _, _, _, _, out), do: out

  defp do_kern_shorten([last_cp], max, cp_metrics, _, k_next, width, out) do
    adv = cp_metrics[last_cp] || cp_metrics[0]

    cond do
      adv + width + k_next <= max -> [last_cp | out]
      true -> out
    end
  end

  defp do_kern_shorten([cp | codepoints], max, cp_metrics, kerning, k_next, w_in, out) do
    width = w_in + (cp_metrics[cp] || cp_metrics[0]) + k_next
    # prep the next k_next
    [cp_next | _] = codepoints
    k_next = Map.get(kerning, {cp, cp_next}, 0)

    cond do
      width <= max ->
        do_kern_shorten(codepoints, max, cp_metrics, kerning, k_next, width, [cp | out])

      true ->
        out
    end
  end

  # --------------------------------------------------------
  @doc """
  Find the gap between to characters given an {x,y} coordinate

  options
  * `:kern` - account for Kerning - true or false

  returns `{character_number, x_position, line_number}`
  """
  def nearest_gap(source, pos, pixels, font_metrics, opts \\ [])

  def nearest_gap(_, {_, y}, _, _, _) when y < 0, do: {0, 0, 0}

  def nearest_gap(
        line,
        {x, _},
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          ascent: ascent,
          descent: descent,
          kerning: kerning,
          version: @version
        },
        opts
      )
      when is_list(line) and is_list(opts) do
    kern = !!opts[:kern]
    # calculate the scaled x and y to use
    scale =
      case pixels do
        nil -> 1.0
        p -> p / (ascent - descent)
      end

    x = x / scale
    do_nearest_gap(line, x, cp_metrics, kerning, kern)
  end

  def nearest_gap(
        source,
        {x, y},
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          ascent: ascent,
          descent: descent,
          kerning: kerning,
          version: @version
        } = fm,
        opts
      )
      when is_bitstring(source) do
    # calculate the scale factor
    scale =
      case pixels do
        nil -> 1.0
        p -> p / (ascent - descent)
      end

    # calculate what line we are interested in
    line_height = opts[:line_height] || pixels
    line_no = trunc(y / line_height)
    lines = String.split(source, "\n")
    line = Enum.at(lines, line_no)

    case line do
      nil ->
        line_no =
          case Enum.count(lines) do
            0 -> 0
            c -> c - 1
          end

        {n, w} =
          case List.last(lines) do
            nil ->
              {0, 0}

            line ->
              {
                String.length(line),
                width(line, pixels, fm, opts) * scale
              }
          end

        # past the last line - put it at the end
        {n, w, line_no}

      line ->
        kern = !!opts[:kern]
        x = x / scale
        line = String.to_charlist(line)
        {n, w} = do_nearest_gap(line, x, cp_metrics, kerning, kern)
        {n, w * scale, line_no}
    end
  end

  # by this point, it should only be one line
  defp do_nearest_gap(line, x, cp_metrics, kerning, kern, k_next \\ 0, width \\ 0, n \\ 0)
  defp do_nearest_gap(_, x, _, _, _, _, _, _) when x <= 0, do: {0, 0}
  defp do_nearest_gap('', _, _, _, _, _, w, n), do: {n, w}

  # non-kerned gap finder
  defp do_nearest_gap([cp | cps], x, cp_metrics, kerning, kern, k_next, width, n) do
    adv = cp_metrics[cp] || cp_metrics[0]
    new_width = width + adv + k_next

    case new_width > x do
      false ->
        # calc the next kerning amount
        k_next =
          case kern do
            false ->
              0

            true ->
              case cps do
                [] -> 0
                [cpn | _] -> kerning[{cp, cpn}] || 0
              end
          end

        # recurse to the next character
        do_nearest_gap(cps, x, cp_metrics, kerning, kern, k_next, new_width, n + 1)

      true ->
        # we are past the test point. Now figure out where the halfway point is
        w_half = width + (adv + k_next) / 2

        cond do
          w_half < x -> {n + 1, new_width}
          true -> {n, width}
        end
    end
  end

  # --------------------------------------------------------
  @doc """
  Returns the coordinates just before the given character number.

  options
  * :kern - account for Kerning - true or false

  returns `{x_position, line_number}`
  """
  def position_at(source, n, pixels, font_metric, opts \\ [])

  def position_at(
        source,
        n,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          ascent: ascent,
          descent: descent,
          kerning: kerning,
          version: @version
        },
        opts
      )
      when is_list(source) do
    kern = !!opts[:kern]

    # calculate the scale factor
    scale =
      case pixels do
        nil -> 1.0
        p -> p / (ascent - descent)
      end

    {x, l} = do_position_at(source, n, cp_metrics, kerning, kern)
    {x * scale, l}
  end

  def position_at(source, n, pixels, fm, opts) when is_bitstring(source) do
    String.to_charlist(source)
    |> position_at(n, pixels, fm, opts)
  end

  defp do_position_at(line, n, cp_metrics, kerning, kern, k_next \\ 0, line_no \\ 0, width \\ 0)

  defp do_position_at('', _, _, _, _, _, line_no, width), do: {width, line_no}
  defp do_position_at(_, -1, _, _, _, _, line_no, width), do: {width, line_no}

  # handle newlines
  defp do_position_at([10 | cps], n, cp_metrics, kerning, kern, _, line_no, _) do
    do_position_at(cps, n - 1, cp_metrics, kerning, kern, 0, line_no + 1, 0)
  end

  defp do_position_at([cp | cps], n, cp_metrics, kerning, kern, k_next, line_no, width) do
    adv = cp_metrics[cp] || cp_metrics[0]
    width = width + adv + k_next
    # calc the next kerning amount
    k_next =
      case kern do
        false ->
          0

        true ->
          case cps do
            [] -> 0
            [cpn | _] -> kerning[{cp, cpn}] || 0
          end
      end

    do_position_at(cps, n - 1, cp_metrics, kerning, kern, k_next, line_no, width)
  end

  # --------------------------------------------------------
  @doc """
  Wraps a string to a given width by adding returns.

  options
  * `:indent` - indent wrapped lines by n spaces or a given string. examples: `indent: 2` or `indent: "___"` or `indent: '...'`
  * `:kern` - account for Kerning - true or false

  returns the wrapped string
  """
  def wrap(source, max_width, pixels, font_metric, opts \\ [])

  def wrap(
        source,
        max_width,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          ascent: ascent,
          descent: descent,
          kerning: kerning,
          version: @version
        } = fm,
        opts
      )
      when is_list(source) and is_list(opts) and max_width > 0 do
    kern = !!opts[:kern]
    # calculate the scaled x and y to use
    scale =
      case pixels do
        nil -> 1.0
        p -> p / (ascent - descent)
      end

    indent =
      case opts[:indent] do
        n when is_integer(n) and n > 0 ->
          Enum.reduce(1..n, [], fn _, s -> [0xA0 | s] end)

        cl when is_list(cl) ->
          cl

        bs when is_bitstring(bs) ->
          String.to_charlist(bs)

        _ ->
          ''
      end

    # calculate the width of the overall indent string
    indent_width = width(indent, pixels, fm, kern) / scale
    # reverse the indent string so it comes out right when the whole thing
    # is reversed at the end
    indent = Enum.reverse(indent)
    max_width = max_width / scale
    do_wrap(source, max_width, indent, indent_width, cp_metrics, kerning, kern, opts)
  end

  def wrap(source, max_width, pixels, fm, opts) when is_bitstring(source) do
    source
    |> String.to_charlist()
    |> wrap(max_width, pixels, fm, opts)
    |> to_string()
  end

  defp do_wrap(
         source,
         max_width,
         indent,
         indent_width,
         cp_metrics,
         kerning,
         kern,
         opts,
         k_next \\ 0,
         width \\ 0,
         out \\ []
       )

  defp do_wrap('', _, _, _, _, _, _, _, _, _, out), do: Enum.reverse(out)

  # handle newlines
  defp do_wrap(
         [10 | cps],
         max_width,
         indent,
         indent_width,
         cp_metrics,
         kerning,
         kern,
         opts,
         _,
         _,
         out
       ) do
    do_wrap(cps, max_width, indent, indent_width, cp_metrics, kerning, kern, opts, 0, 0, [
      10 | out
    ])
  end

  # core wrapping function
  defp do_wrap(
         [cp | cps],
         max_width,
         indent,
         indent_width,
         cp_metrics,
         kerning,
         kern,
         opts,
         k_next,
         width,
         out
       ) do
    adv = cp_metrics[cp] || cp_metrics[0]
    new_width = width + adv + k_next
    # calc the next kerning amount
    k_next =
      case kern do
        false ->
          0

        true ->
          case cps do
            [] -> 0
            [cpn | _] -> kerning[{cp, cpn}] || 0
          end
      end

    # if we are past the wrap point, then wrap and reset the counters
    case new_width > max_width do
      true ->
        out = [10 | out]
        out = indent ++ out
        out = [cp | out]

        do_wrap(
          cps,
          max_width,
          indent,
          indent_width,
          cp_metrics,
          kerning,
          kern,
          opts,
          0,
          indent_width,
          out
        )

      false ->
        out = [cp | out]

        do_wrap(
          cps,
          max_width,
          indent,
          indent_width,
          cp_metrics,
          kerning,
          kern,
          opts,
          k_next,
          new_width,
          out
        )
    end
  end

  # defp indent_wrap( out, n ) when n <= 0, do: out
  # defp indent_wrap( out, n ), do: indent_wrap( [ 32 | out], n - 1 )
end
