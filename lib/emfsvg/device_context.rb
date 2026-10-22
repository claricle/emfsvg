# frozen_string_literal: true

module Emfsvg
  # Coordinate state that lives OUTSIDE the device-context stack in
  # libemf2svg (MapMode, window/viewport extents and origins). The C
  # code keeps these on drawingStates directly, NOT on
  # EMF_DEVICE_CONTEXT, so SaveDC/RestoreDC never saves/restores them.
  # They persist as global state for the duration of the render.
  #
  # This is a mutable struct shared by reference across every dup'd
  # DeviceContext — when visit_set_map_mode changes the map mode, every
  # DC observes the new value, even ones that were saved earlier.
  class CoordinateState
    attr_accessor :map_mode, :window_ext, :viewport_ext,
                  :window_org, :viewport_org,
                  :window_ext_set, :viewport_ext_set

    def initialize
      @map_mode = 1 # MM_TEXT
      @window_ext = [0, 0]
      @viewport_ext = [0, 0]
      @window_org = [0, 0]
      @viewport_org = [0, 0]
      @window_ext_set = false
      @viewport_ext_set = false
    end
  end

  # Snapshot of GDI drawing state. Pushed onto TransformStack on SaveDC,
  # popped on RestoreDC.
  class DeviceContext
    def initialize
      @pen = Pen.default
      @brush = Brush.default
      @font = Font.default
      @text_color = Emf::Model::Geometry::Color.black
      @bk_color = Emf::Model::Geometry::Color.white
      @bk_mode = 1 # TRANSPARENT
      @poly_fill_mode = 1 # ALTERNATE (evenodd)
      @text_align = 0
      @stretch_mode = 1
      @miter_limit = 10.0
      @world_transform = Emf::Model::Geometry::Matrix.identity
      @brush_origin = [0, 0]
      @icm_mode = 0
      @layout = 0
      @mapper_flags = 0
      @arc_direction = 0 # default; set by SetArcDirection (1=CW, -1=CCW in C)
      @clip_region = nil
      @clip_id = nil
      # Coordinate state shared across all dup'd DCs (see CoordinateState).
      @coordinate_state = CoordinateState.new
    end

    attr_accessor :pen, :brush, :font, :text_color, :bk_color, :bk_mode, :poly_fill_mode, :text_align,
                  :stretch_mode, :miter_limit, :world_transform, :brush_origin, :icm_mode, :layout,
                  :mapper_flags, :arc_direction, :clip_region, :clip_id, :coordinate_state

    def map_mode
      coordinate_state.map_mode
    end

    def map_mode=(value)
      coordinate_state.map_mode = value
    end

    def window_ext
      coordinate_state.window_ext
    end

    def window_ext=(value)
      coordinate_state.window_ext = value
    end

    def viewport_ext
      coordinate_state.viewport_ext
    end

    def viewport_ext=(value)
      coordinate_state.viewport_ext = value
    end

    def window_org
      coordinate_state.window_org
    end

    def window_org=(value)
      coordinate_state.window_org = value
    end

    def viewport_org
      coordinate_state.viewport_org
    end

    def viewport_org=(value)
      coordinate_state.viewport_org = value
    end

    def window_ext_set?
      coordinate_state.window_ext_set
    end

    def viewport_ext_set?
      coordinate_state.viewport_ext_set
    end

    def window_ext_set=(value)
      coordinate_state.window_ext_set = value
    end

    def viewport_ext_set=(value)
      coordinate_state.viewport_ext_set = value
    end

    def dup
      other = DeviceContext.allocate
      # Pen, Brush, Font, Matrix and the brush origin are never mutated in
      # place (handlers replace them), so snapshots share them.
      other.pen = pen
      other.brush = brush
      other.font = font
      other.text_color = text_color
      other.bk_color = bk_color
      other.bk_mode = bk_mode
      other.poly_fill_mode = poly_fill_mode
      other.text_align = text_align
      other.stretch_mode = stretch_mode
      other.miter_limit = miter_limit
      other.world_transform = world_transform
      other.brush_origin = brush_origin
      other.icm_mode = icm_mode
      other.layout = layout
      other.mapper_flags = mapper_flags
      other.arc_direction = arc_direction
      other.clip_region = clip_region
      other.clip_id = clip_id
      # CoordinateState is shared by reference — SaveDC/RestoreDC must
      # not snapshot/restore the coordinate state per libemf2svg.
      other.coordinate_state = coordinate_state
      other
    end

    protected :coordinate_state=
  end

  # Pen value object: style, width, color.
  class Pen
    SOLID = 0
    DASH = 1
    DOT = 2
    DASHDOT = 3
    DASHDOTDOT = 4
    NULL = 5
    INSIDEFRAME = 6

    def initialize(style: SOLID, width: 1, color: Emf::Model::Geometry::Color.black)
      @style = style
      @width = width
      @color = color
    end

    attr_reader :style, :width, :color

    def self.default
      new
    end

    def null?
      style == NULL
    end

    def dup
      Pen.new(style: style, width: width, color: color)
    end
  end

  # Brush value object: style, color, hatch.
  class Brush
    SOLID = 0
    NULL = 1
    HATCHED = 2
    PATTERN = 3
    # MONOPATTERN: 8 (BS_MONOPATTERN / U_BS_MONOPATTERN in MS-WMF). Brush
    # references a DIB image stored in the SVG <defs>; fill becomes
    # `url(#img-N-ref)`. brush.image_id is the N.
    MONOPATTERN = 8

    def initialize(style: SOLID, color: Emf::Model::Geometry::Color.black, hatch: 0, image_id: nil)
      @style = style
      @color = color
      @hatch = hatch
      @image_id = image_id
    end

    attr_reader :style, :color, :hatch, :image_id

    def self.default
      new
    end

    def null?
      style == NULL
    end

    def dup
      Brush.new(style: style, color: color, hatch: hatch, image_id: image_id)
    end
  end

  # Font value object: minimal subset of LOGFONT for text rendering.
  class Font
    DEFAULT_HEIGHT = 0

    def initialize(face_name: nil, height: DEFAULT_HEIGHT, weight: 0,
                   italic: false, underline: false, strikeout: false,
                   escapement: 0, charset: 0)
      @face_name = face_name
      @height = height
      @weight = weight
      @italic = italic
      @underline = underline
      @strikeout = strikeout
      @escapement = escapement
      @charset = charset
    end

    attr_reader :face_name, :height, :weight, :italic, :underline, :strikeout, :escapement, :charset

    def self.default
      new
    end

    def bold?
      weight >= 700
    end

    def dup
      Font.new(face_name: face_name, height: height, weight: weight,
               italic: italic, underline: underline, strikeout: strikeout,
               escapement: escapement, charset: charset)
    end
  end
end
