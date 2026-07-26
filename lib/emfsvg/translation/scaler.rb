# frozen_string_literal: true

module Emfsvg
  module Translation
    # Coordinate scalers convert SVG decimal coordinates to EMF int32
    # coordinates. The default Identity scaler truncates (matching
    # MM_TEXT mode 1:1). The Fixed scaler multiplies by a constant
    # factor so decimal places are preserved as integer fractions.
    #
    # When the Fixed scaler is in use, the renderer also emits
    # SetMapMode(MM_ANISOTROPIC) + SetWindowExtEx + SetViewportExtEx
    # so emfsvg's EMF→SVG renderer computes `sf_x = 1 / factor` and
    # divides back to recover the original decimal value.
    module Scaler
      autoload :Identity, "emfsvg/translation/scaler/identity"
      autoload :Fixed, "emfsvg/translation/scaler/fixed"
    end
  end
end
