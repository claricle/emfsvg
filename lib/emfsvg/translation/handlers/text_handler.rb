# frozen_string_literal: true

require "emf"

module Emfsvg
  module Translation
    module Handlers
      # Translate <text> to CreateFontIndirectW + SetTextColor +
      # ExtTextOutW + DeleteObject.
      #
      # v1 limitations:
      #   * ASCII / BMP characters only (UTF-16LE encoding).
      #   * No glyph-index path (ETO_GLYPH_INDEX).
      #   * No Dx array (character spacing defaults to natural advance).
      #   * LOGFONT built with default OutPrecision/ClipPrecision/Quality.
      class TextHandler
        include SharedGdi
        include Emf::Emr::Binary::TypeCodes

        LOGFONT_SIZE = 92
        EXTTEXTOUTW_FIXED_SIZE = 76

        def self.call(element, context)
          new.translate(element, context)
        end

        def translate(element, context)
          return if element.content.nil?
          return if element.content.empty? && !element.empty_cdata_content && !element.font_size.zero?

          clip_bounds = clip_bounds_for(element, context)
          wrap_with_clip = !clip_bounds.nil?
          transformed = element.transformed?

          signature = clip_scope_signature(element, context, clip_bounds)
          reuse_clip = context.reuse_clip_scope?(signature)
          emit_save_dc(context) if (wrap_with_clip || transformed) && !reuse_clip
          if transformed
            context.emit(Emf::Emr::Binary::Records::SetWorldTransform,
                         i_type: SETWORLDTRANSFORM,
                         xform: context.xform_wire_from(element.transform_matrix))
          end
          if wrap_with_clip && !reuse_clip
            context.emit(Emf::Emr::Binary::Records::IntersectClipRect,
                         i_type: INTERSECTCLIPRECT,
                         rcl_clip: context.rect_attrs(*clip_bounds))
          end
          emit_text(element, context, reuse: !wrap_with_clip && !transformed)
          return unless wrap_with_clip || transformed

          restore = emit_restore_dc(context)
          context.remember_clip_scope(signature, restore)
        end

        private

        def emit_text(element, context, reuse:)
          # Packed LOGFONT includes rotation, weight, size, family and italic;
          # positions and content may vary without changing selected GDI state.
          signature = [build_logfont(element, context), element.fill.color.wire_attrs, text_align(element)] if reuse
          font_handle = context.reuse_text_state(signature)
          unless font_handle
            font_handle = emit_create_font(element, context)
            emit_set_text_color(element, context)
            emit_set_text_align(element, context)
          end
          emit_ext_text_out_w(element, context)
          deletion = emit_delete(context, font_handle)
          context.remember_text_state(signature, font_handle, deletion)
        end

        def emit_create_font(element, context)
          handle = context.allocate_handle
          logfont_bytes = build_logfont(element, context)
          context.emit(Emf::Emr::Binary::Records::CreateFontIndirectW,
                       i_type: EXTCREATEFONTINDIRECTW,
                       ih_object: handle,
                       body: logfont_bytes)
          context.emit(Emf::Emr::Binary::Records::SelectObject,
                       i_type: SELECTOBJECT,
                       ih_object: handle)
          handle
        end

        def emit_set_text_color(element, context)
          color = element.fill.color.wire_attrs
          context.emit(Emf::Emr::Binary::Records::SetTextColor,
                       i_type: SETTEXTCOLOR,
                       color: color)
        end

        def text_align(element)
          case element.text_anchor
          when "middle" then 0x1E # TA_CENTER | TA_BASELINE
          when "end" then 0x1A # TA_RIGHT | TA_BASELINE
          else 0x18 # TA_LEFT | TA_BASELINE
          end
        end

        def emit_set_text_align(element, context)
          context.emit(Emf::Emr::Binary::Records::SetTextAlign,
                       i_type: SETTEXTALIGN,
                       text_align_mode: text_align(element))
        end

        def emit_ext_text_out_w(element, context)
          text_utf16 = element.content.encode("UTF-16LE").force_encoding("ASCII-8BIT")
          n_chars = element.content.length
          off_string = EXTTEXTOUTW_FIXED_SIZE
          # The Dx array starts on a DWORD boundary, including after odd-length text.
          off_dx = (off_string + text_utf16.bytesize + 3) & ~3
          dx_bytes = ("\x00" * 4) * n_chars # zero Dx — natural advance

          bounds = text_bounds(element, context)
          context.emit(Emf::Emr::Binary::Records::ExtTextOutW,
                       i_type: EXTTEXTOUTW,
                       rcl_bounds: bounds,
                       i_graphics_mode: 2, # GM_COMPATIBLE
                       ex_scale: 1.0,
                       ey_scale: 1.0,
                       ptl_reference: context.point_attrs(element.x, element.y),
                       n_chars: n_chars,
                       off_string: off_string,
                       f_options: 0,
                       rcl: context.rect_attrs(0, 0, 0, 0),
                       off_dx: off_dx,
                       trailing: text_utf16.ljust(off_dx - off_string, "\x00") + dx_bytes)
        end

        # Pack a LOGFONT struct (92 bytes) per MS-WMF 2.2.13.
        def build_logfont(element, context)
          face_utf16 = (element.font_family || "").encode("UTF-16LE")
          face_padded = face_utf16.ljust(64, "\x00".encode("UTF-16LE"))
          face_bytes = face_padded.bytes.pack("C*")[0, 64]

          scaled_height = context.scaler.to_int(element.font_size)
          [
            scaled_height, # lfHeight (scaled)
            0, # lfWidth
            -element.font.rotation.to_i * 10, # lfEscapement (tenths of a degree)
            0,                                # lfOrientation
            element.font_weight.to_i,         # lfWeight
            element.italic? ? 1 : 0,          # lfItalic
            0,                                # lfUnderline
            0,                                # lfStrikeOut
            0,                                # lfCharSet
            0,                                # lfOutPrecision
            0,                                # lfClipPrecision
            0,                                # lfQuality
            0                                 # lfPitchAndFamily
          ].pack("l<l<l<l<l<CCCCCCCC") + face_bytes
        end

        def text_bounds(element, context)
          width = element.content.length * element.font_size * 0.6
          context.rect_attrs(
            element.x, element.y - element.font_size,
            element.x + width, element.y
          )
        end
      end
    end
  end
end
