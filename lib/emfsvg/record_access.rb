# frozen_string_literal: true

module Emfsvg
  # How the renderer reads one parsed record: its wire class without making
  # the wire, and its field values without making BinData field objects.
  #
  # emf's `WireAdapter#wire_class` and `#values` are used on a record that has
  # `wire_class` (added with `values` in the same emf); any other record, or an emf without them, gives the wire. Its
  # accessors have the same names, so every caller reads either one the
  # same way.
  module RecordAccess
    # Wire classes whose handlers read fields only through names and Integer
    # or Float values that the value view shares with the wire (nested
    # structs and point arrays included). Handlers of other classes, such as
    # text, bitmaps and objects with a body, receive the wire.
    VALUE_CLASSES = %w[
      SelectObject DeleteObject CreatePen CreateBrushIndirect SetBkColor SetTextColor SetBkMode
      SetTextAlign SetMapMode SetPolyFillMode SetRop2 SetStretchBltMode SetMiterLimit SetIcmMode
      SetLayout SaveDc RestoreDc SetWindowOrgEx SetWindowExtEx SetViewportOrgEx SetViewportExtEx
      SetBrushOrgEx SetWorldTransform ModifyWorldTransform MoveToEx LineTo Rectangle Ellipse SetPixelV
      IntersectClipRect ExcludeClipRect BeginPath EndPath CloseFigure FillPath StrokePath
      StrokeAndFillPath Polygon Polyline PolyBezier PolyBezierTo PolylineTo Polygon16 Polyline16
      PolyBezier16 PolyBezierTo16 PolylineTo16
    ].to_h { |name| [Emf::Emr::Binary::Records.const_get(name), true] }.compare_by_identity.freeze

    module_function

    # The wire class of the record.
    def wire_class(record)
      record.respond_to?(:wire_class) ? record.wire_class : record.wire.class
    end

    # What the handler of a `klass` record reads its fields from.
    def fields(record, klass)
      (record.values if VALUE_CLASSES[klass] && record.respond_to?(:wire_class)) || record.wire
    end
  end
end
