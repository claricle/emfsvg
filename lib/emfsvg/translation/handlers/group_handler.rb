# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <g> into SaveDC + SetWorldTransform (if transformed) +
      # children + RestoreDC. Matches EMF→SVG's reverse transform_group
      # emission.
      class GroupHandler
        include Emf::Emr::Binary::TypeCodes

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          context.emit(Emf::Emr::Binary::Records::SaveDc, i_type: SAVEDC)
          # Always emit SetWorldTransform — emfsvg's EMF→SVG renderer
          # emits `<g transform="matrix(...)">` for every SetWorldTransform
          # record, regardless of whether the matrix is identity. Skipping
          # it would drop the group wrapper from the round-tripped SVG.
          emit_world_transform(element.transform_matrix, context)
          element.children.each { |child| context.dispatch(child) }
          context.emit(Emf::Emr::Binary::Records::RestoreDc,
                       i_type: RESTOREDC, saved_dc: -1)
        end

        private

        def emit_world_transform(matrix, context)
          context.emit(Emf::Emr::Binary::Records::SetWorldTransform,
                       i_type: SETWORLDTRANSFORM,
                       xform: context.xform_wire_from(matrix))
        end
      end
    end
  end
end
