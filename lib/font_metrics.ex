#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019-2021 Kry10 Industries. All rights reserved.
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
      {:font_metrics, "~> 0.5"}
    ]
  end
  ```

  ## Generating Metrics

  You will need to use another package to compile the font metrics data from a font.

  This can be done with the truetype_metrics package. Look for it on hex...
  """

  # This represents the version of the data format, not the hex package.
  # Hopefully, it doesn't change much if at all...
  @version "0.1.1"
  @point_to_pixel_ratio 4 / 3

  # import IEx

  # ===========================================================================

  @type t :: %FontMetrics{
          version: String.t(),
          source: FontMetrics.Source.t(),
          direction: nil,
          smallest_ppem: integer,
          units_per_em: integer,
          max_box: {x_min :: integer, y_min :: integer, x_max :: integer, y_max :: integer},
          ascent: integer,
          descent: integer,
          line_gap: integer,
          metrics: %{integer => number},
          kerning: %{{integer, integer} => number}
        }

  defstruct version: nil,
            source: nil,
            direction: nil,
            smallest_ppem: nil,
            units_per_em: nil,
            max_box: nil,
            ascent: nil,
            descent: nil,
            line_gap: 0,
            metrics: %{},
            kerning: %{}

  @kern_option_schema [kern: [type: :boolean, default: false]]

  # ===========================================================================
  defmodule Error do
    @moduledoc false
    defexception message: "", error: nil, data: nil
  end

  # ============================================================================
  # high-level functions

  def version(), do: @version
  def expected_hash(), do: :sha256

  # ============================================================================
  # validity checks

  # --------------------------------------------------------
  @doc """
  Checks if all the characters can be rendered by the font

  returns `true` or `false`
  """
  @spec supported?(
          codepoint :: integer | list(integer) | binary,
          metrics :: FontMetrics.t()
        ) :: boolean
  def supported?(codepoint, %FontMetrics{metrics: metrics})
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
  @spec ascent(pixels :: number, metrics :: FontMetrics.t()) :: number
  def ascent(pixels, font_metrics)
  def ascent(nil, %FontMetrics{ascent: ascent}), do: ascent

  def ascent(pixels, %FontMetrics{ascent: ascent, units_per_em: u_p_m}) do
    ascent * pixels / u_p_m
  end

  # --------------------------------------------------------
  @doc """
  Get the descent of the font scaled to the pixel height

  returns `descent`
  """
  @spec descent(pixels :: number, metrics :: FontMetrics.t()) :: number
  def descent(pixels, font_metrics)
  def descent(nil, %FontMetrics{descent: descent}), do: descent

  def descent(pixels, %FontMetrics{descent: descent, units_per_em: u_p_m}) do
    descent * pixels / u_p_m
  end

  # --------------------------------------------------------
  @doc """
  Transform point values into pixels

  returns `pixels`
  """
  @spec points_to_pixels(pixels :: number) :: number
  def points_to_pixels(points) when is_number(points), do: points * @point_to_pixel_ratio

  # --------------------------------------------------------
  @doc """
  Return a box that would hold the largest character in the font.

  The response is scaled to the pixel size.

  returns `{x_min, y_min, x_max, y_max}`
  """
  @spec max_box(pixels :: number, metrics :: FontMetrics.t()) ::
          {x_min :: number, y_min :: number, x_max :: number, y_max :: number}
  def max_box(pixels, font_metrics)
  def max_box(nil, %FontMetrics{max_box: max_box}), do: max_box

  def max_box(
        pixels,
        %FontMetrics{
          max_box: {x_min, y_min, x_max, y_max},
          units_per_em: u_p_m
        }
      ) do
    scale = pixels / u_p_m
    {x_min * scale, y_min * scale, x_max * scale, y_max * scale}
  end

  # --------------------------------------------------------
  @doc """
  Measure the width of a string, scaled to a pixel size

  ## Options
  Supported options:\n#{NimbleOptions.docs(@kern_option_schema)}

  returns `width`
  """
  @spec width(
          String.t() | integer | list(integer),
          pixels :: number,
          metrics :: FontMetrics.t(),
          opts :: Keyword.t()
        ) :: number
  def width(source, pixels, font_metrics, opts \\ [])

  def width("", _, _, _), do: 0
  def width('', _, _, _), do: 0

  def width(
        source,
        nil,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning
        },
        opts
      )
      when is_list(opts) do
    opts = NimbleOptions.validate!(opts, @kern_option_schema)

    do_width(source, 1.0, cp_metrics, kerning, opts[:kern])
  end

  def width(
        source,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning,
          units_per_em: u_p_m
        },
        opts
      )
      when is_number(pixels) and pixels > 0 and is_list(opts) do
    opts = NimbleOptions.validate!(opts, @kern_option_schema)

    scale = pixels / u_p_m
    do_width(source, scale, cp_metrics, kerning, opts[:kern])
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
  @shorten_options_schema [
    kern: [type: :boolean, default: false],
    terminator: [type: :string, default: "…"]
  ]

  @doc """
  Shorten a string to fit a given width

  ## Options
  Supported options:\n#{NimbleOptions.docs(@shorten_options_schema)}

  returns `string`
  """

  @spec shorten(
          String.t() | list(integer),
          max_width :: number,
          pixels :: number,
          metrics :: FontMetrics.t(),
          opts :: Keyword.t()
        ) :: String.t() | list(integer)

  def shorten(source, max_width, pixels, font_metrics, opts \\ [])

  def shorten(
        source,
        max_width,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning,
          units_per_em: u_p_m
        } = font_metrics,
        opts
      )
      when is_list(source) and is_list(opts) do
    opts = NimbleOptions.validate!(opts, @shorten_options_schema)

    terminator = String.to_charlist(opts[:terminator])

    # calculate the scale to use
    scale = pixels / u_p_m

    # terminator_width = do_width( terminator, scale, font_metrics, kern )
    terminator_width = do_width(terminator, scale, cp_metrics, kerning, opts[:kern])

    do_shorten(
      source,
      max_width - terminator_width,
      scale,
      font_metrics,
      opts[:kern]
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

  defp do_shorten(_, max_width, _, _, _) when max_width <= 0, do: ''

  # various ways to structure the code. This attempts to reuse calculations and
  # and keep it to a single pass as much as possible
  # no kerning
  defp do_shorten(
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
  defp do_shorten(
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
  @gap_options_schema [
    kern: [type: :boolean, default: false],
    wrap: [type: {:in, [:word, :char]}, default: :word],
    line_height: [type: {:custom, __MODULE__, :validate_number, [:line_height]}]
  ]

  @doc """
  Find the gap between to characters given an {x,y} coordinate

  ## Options
  Supported options:\n#{NimbleOptions.docs(@gap_options_schema)}

  returns `{character_number, x_position, line_number}`
  """
  @spec nearest_gap(
          String.t() | list(integer),
          pos :: {number, number},
          pixels :: number,
          metrics :: FontMetrics.t(),
          opts :: Keyword.t()
        ) :: {character_number :: integer, x_position :: number, line_number :: integer}
  def nearest_gap(source, pos, pixels, font_metrics, opts \\ [])

  def nearest_gap(_, {_, y}, _, _, _) when y < 0, do: {0, 0, 0}

  def nearest_gap(
        line,
        {x, _},
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning,
          units_per_em: u_p_m
        },
        opts
      )
      when is_list(line) and is_list(opts) do
    opts = NimbleOptions.validate!(opts, @kern_option_schema)

    # calculate the scaled x and y to use
    scale = pixels / u_p_m

    x = x / scale
    do_nearest_gap(line, x, cp_metrics, kerning, opts[:kern])
  end

  def nearest_gap(
        source,
        {x, y},
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning,
          units_per_em: u_p_m
        } = fm,
        opts
      )
      when is_bitstring(source) do
    opts = NimbleOptions.validate!(opts, @gap_options_schema)

    scale = pixels / u_p_m

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
        x = x / scale
        line = String.to_charlist(line)
        {n, w} = do_nearest_gap(line, x, cp_metrics, kerning, opts[:kern])
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

  ## Options
  Supported options:\n#{NimbleOptions.docs(@kern_option_schema)}

  returns `{x_position, line_number}`
  """

  @spec position_at(
          String.t() | list(integer),
          character_index :: number,
          pixels :: number,
          metrics :: FontMetrics.t(),
          opts :: Keyword.t()
        ) :: {x :: number, line :: integer}

  def position_at(source, n, pixels, font_metric, opts \\ [])

  def position_at(
        source,
        n,
        pixels,
        %FontMetrics{
          metrics: cp_metrics,
          kerning: kerning,
          units_per_em: u_p_m
        },
        opts
      )
      when is_list(source) do
    opts = NimbleOptions.validate!(opts, @kern_option_schema)

    # calculate the scale factor
    scale = pixels / u_p_m

    {x, l} = do_position_at(source, n, cp_metrics, kerning, opts[:kern])
    {x * scale, l}
  end

  def position_at(source, n, pixels, fm, opts) when is_bitstring(source) do
    String.to_charlist(source)
    |> position_at(n, pixels, fm, opts)
  end

  defp do_position_at(line, n, cp_metrics, kerning, kern, k_next \\ 0, line_no \\ 0, width \\ 0)

  defp do_position_at('', _, _, _, _, _, line_no, width), do: {width, line_no}
  defp do_position_at(_, p, _, _, _, _, line_no, width) when p <= 0, do: {width, line_no}

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

  @wrap_options_schema [
    wrap: [type: {:in, [:word, :char]}, default: :word],
    kern: [type: :boolean, default: false]
  ]

  @doc """
  Wraps a string to a given width by adding returns.

  ## Options
  Supported options:\n#{NimbleOptions.docs(@wrap_options_schema)}

  returns the wrapped string
  """

  @spec wrap(
          String.t() | list(integer),
          max_width :: number,
          pixels :: number,
          metrics :: FontMetrics.t(),
          opts :: Keyword.t()
        ) :: String.t() | list(integer)

  def wrap(source, max_width, pixels, font_metric, opts \\ [])

  def wrap(source, max_width, pixels, fm, opts)
      when is_bitstring(source) and is_list(opts) and max_width > 0 do
    opts = NimbleOptions.validate!(opts, @wrap_options_schema)

    case opts[:wrap] do
      :char ->
        do_wrap_chars(source, max_width, pixels, fm, opts)

      :word ->
        source
        |> String.split(" ")
        |> do_wrap_words(max_width, pixels, fm, opts)
    end
  end

  defp do_wrap_chars(chars, max_width, pixels, fm, opts, line \\ "", lines \\ [])
  defp do_wrap_chars("", _, _, _, _, "", lines), do: end_wrap(lines)
  defp do_wrap_chars("", _, _, _, _, line, lines), do: end_wrap([line | lines])

  defp do_wrap_chars(text, max_width, pixels, fm, opts, line, lines) do
    # split the text as if it was a list
    {cp, tail} = String.split_at(text, 1)

    # directly join the cp and the current line
    test_line = line <> cp

    # test if new_out goes past max_width. If it does, return it there
    case width(test_line, pixels, fm, kern: opts[:kern]) > max_width do
      # too long
      true ->
        do_wrap_chars(text, max_width, pixels, fm, opts, "", [line | lines])

      # keep going
      false ->
        do_wrap_chars(tail, max_width, pixels, fm, opts, test_line, lines)
    end
  end

  defp do_wrap_words(words, max_width, pixels, fm, opts, line \\ "", lines \\ [])
  defp do_wrap_words([], _, _, _, _, "", lines), do: end_wrap(lines)
  defp do_wrap_words([], _, _, _, _, line, lines), do: end_wrap([line | lines])

  defp do_wrap_words([w | tail] = words, max_width, pixels, fm, opts, line, lines) do
    test_line =
      Enum.join([line, w], " ")
      |> String.trim()

    # test if new_out goes past max_width. If it does, return it there
    case width(test_line, pixels, fm, kern: opts[:kern]) > max_width do
      # too long
      true ->
        do_wrap_words(words, max_width, pixels, fm, opts, "", [line | lines])

      # keep going
      false ->
        do_wrap_words(tail, max_width, pixels, fm, opts, test_line, lines)
    end
  end

  defp end_wrap(lines) do
    lines
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  # ================================

  # validate that an opt is a number. not just an integer.
  # example: 1.5 is sometimes acceptable.
  def validate_number(n, _) when is_number(n), do: {:ok, n}

  def validate_number(n, name) do
    {
      :error,
      """
      #{IO.ANSI.red()}The #{inspect(name)} option must be nil or a number
      #{IO.ANSI.yellow()}Received: #{inspect(n)}
      #{IO.ANSI.default_color()}
      """
    }
  end
end
