#
#  Created by Boyd Multerer on 2/13/18.
#  Copyright © 2018 Kry10 Industries. All rights reserved.
#
#  helpers for known unicode ranges
#
defmodule FontMetrics.Ranges do

#  import IEx

  defstruct cmap: %{}, pixels: nil, width: 0, height: 0

  #--------------------------------------------------------
  def intersect( ranges_a, ranges_b ) do
    ranges_a = simplify( ranges_a )
    ranges_b = simplify( ranges_b )
    do_intersect( ranges_a, ranges_b )
  end

  defp do_intersect( a, b, intersection \\ [] )
  defp do_intersect( a, b, intersection ) do
    Enum.reduce(a, intersection, fn(a_one, intersect) ->
      [do_intersect_one(b, a_one) | intersect]
    end)
    |> List.flatten()
    |> Enum.reverse()
  end

  defp do_intersect_one(range, one, acc \\ [])
  defp do_intersect_one([], _, acc), do: acc

  # no overlap, and wont be either as it is sorted
  defp do_intersect_one([{bs, _} | _], {_, af}, acc) when af < bs, do: acc

  # no overlap, but later ones might
  defp do_intersect_one([{_, bf} | tail], {as, af}, acc) when as > bf do
    do_intersect_one(tail, {as, af}, acc)
  end

  # yes overlap
  defp do_intersect_one([{bs, bf} | tail], {as, af}, acc) do
    do_intersect_one(tail, {as, af}, [{ceiling(as, bs), floor(af, bf)} | acc])
  end


  #--------------------------------------------------------
  def simplify( ranges ) do
    ranges
    |> interpret()
    |> Enum.sort()
    |> do_simplify()
    |> Enum.reverse()
  end

  defp do_simplify( complex, simplified \\ [] )
  defp do_simplify( [], simplified ), do: simplified
  defp do_simplify( [head | []], simplified ), do: [head | simplified]
  defp do_simplify( [{hs, hf} | [{ns, nf} | tail]], simplified ) do
    cond do
      ns > hf + 1 ->
        # not adjacent - no overlap. keep them
        do_simplify( [{ns, nf} | tail], [{hs, hf} | simplified] )

      true ->
        # at this point we know there is either overlap or adjacency.
        # combine and resubmit for simplification against the next one 
        do_simplify( [{floor(hs, ns), ceiling(hf, nf)} | tail], simplified )
    end
  end


  #--------------------------------------------------------
  def to_charlist( ranges, opts \\ [] ) do
    include_control = opts[:control]

    ranges
    |> simplify
    |> Enum.reduce([], fn({start, finish}, acc) ->
      Enum.reduce(start .. finish, acc, fn(ch, ac) ->
        if include_control do
          # Include control characters
          [ch | ac]
        else
          # strip control characters
          cond do
            ch < 32 -> ac                       # common control characters
            ch >= 0x7F && ch <= 0x09F -> ac     # ascii control range
            ch >= 0xFFF9 && ch <= 0xFFFF -> ac  # unicode control range
            ch > 0x10FFFF -> ac                 # invalid codepoints
            true -> [ch | ac] 
          end
        end
      end)
    end)
    |> List.flatten()
    |> Enum.reverse()
  end


  #--------------------------------------------------------
  def interpret( ranges ) when is_list(ranges) do
    Enum.reduce(ranges, [], fn(r, acc) ->
      [ interpret(r) | acc ]
    end)
    |> List.flatten()
    |> Enum.reverse()
  end

  def interpret( {start, finish} ) when is_integer(start) and is_integer(finish)
  and start <= finish do
    [{start, finish}]
  end

  def interpret( {start, finish} ) when is_integer(start) and is_integer(finish) do
    [{finish, start}]
  end

  def interpret( :latin ),                do: interpret( [:latin_1, :latin_1_supplement] )
  def interpret( :latin_extended ),       do: interpret( [:latin_1, :latin_1_supplement, :latin_extended_a, :latin_extended_b] )

  def interpret( :numbers ),              do: [{0x002C, 0x002D}, {0x0030, 0x0039}]
  def interpret( :numbers_extended ),     do: [{0x0020, 0x0040}]

  def interpret( :control ),              do: [{0x0000, 0x0019}, {0x007F, 0x009F}, {0xFFF9, 0xFFFF}]
  def interpret( :latin_1 ),              do: [{0x0020, 0x007F}]
  def interpret( :latin_1_supplement ),   do: [{0x0080, 0x00FF}]
  def interpret( :latin_extended_a ),     do: [{0x0100, 0x017F}]
  def interpret( :latin_extended_b ),     do: [{0x0180, 0x024F}]
  def interpret( :ipa_extensions ),       do: [{0x0250, 0x02AF}]

  def interpret( :greek_coptic ),         do: [{0x0370, 0x03FF}]
  def interpret( :cyrillic ),             do: [{0x0400, 0x04FF}]
  def interpret( :cyrillic_supplement ),  do: [{0x0500, 0x052F}]
  def interpret( :armenian ),             do: [{0x0530, 0x058F}]
  def interpret( :hebrew ),               do: [{0x0590, 0x05FF}]
  def interpret( :arabic ),               do: [{0x0600, 0x06FF}]



  #============================================================================
  # internal utilities

  defp floor(a, b) when a <= b, do: a
  defp floor(_, b), do: b

  defp ceiling(a, b) when a >= b, do: a
  defp ceiling(_, b), do: b



end