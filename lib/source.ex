#
#  Created by Boyd Multerer on 25/02/19.
#  Copyright © 2019-2021 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics.Source do
  @moduledoc """
  Struct defining source information for a font metrics term.


  """

  @type t :: %FontMetrics.Source{
          signature: binary,
          signature_type: :sha_256 | :sha3_256 | :sha3_512,
          font_type: :true_type,
          created_at: DateTime.t(),
          modified_at: DateTime.t(),
          file: String.t()
        }

  defstruct signature: nil,
            signature_type: nil,
            font_type: nil,
            created_at: nil,
            modified_at: nil,
            file: nil
end
