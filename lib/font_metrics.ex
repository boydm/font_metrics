#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics do
  @moduledoc """
  Documentation for FontMetrics.
  """

  import IEx

  @signature_type   :sha256

  defstruct source: nil, direction: nil, smallest_ppem: nil, codepoint_count: 0,
    units_per_em: nil, max_box: nil, ranges: [], kerning: %{}, style: nil,
    default_advance: nil, advances: %{}

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
  def is_supported?( codepoint, %FontMetrics{ranges: ranges} ) when is_integer(codepoint) do
    !!Enum.find(ranges, fn({first,last}) ->
      codepoint >= first && codepoint <= last
    end)
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
  # measurement math

  #--------------------------------------------------------
  def string_width( string, point_size, %FontMetrics{} = metrics ) when
  is_bitstring(string) and is_number(point_size) and point_size > 0 do
  end

  #--------------------------------------------------------
  def string_height( string, point_size, %FontMetrics{} = metrics ) when
  is_bitstring(string) and is_number(point_size) and point_size > 0 do
  end

  #--------------------------------------------------------
  def string_bounds( string, point_size, %FontMetrics{} = metrics ) when
  is_bitstring(string) and is_number(point_size) and point_size > 0 do
  end

end