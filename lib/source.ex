#
#  Created by Boyd Multerer on 25/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule FontMetrics.Source do
  @moduledoc """
  Struct defining source information for a font metrics term.


  """

  @derive Msgpax.Packer
  defstruct signature: nil,
            signature_type: nil,
            font_type: nil,
            created_at: nil,
            modified_at: nil,
            file: nil
end
