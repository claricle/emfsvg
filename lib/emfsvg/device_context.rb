# frozen_string_literal: true

module Emfsvg
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
      @map_mode = 1 # MM_TEXT
      @text_align = 0
      @stretch_mode = 1
      @miter_limit = 10.0
      @world_transform = Emf::Model::Geometry::Matrix.identity
    end

    attr_accessor :pen, :brush, :font, :text_color, :bk_color, :bk_mode,
                  :poly_fill_mode, :map_mode, :text_align, :stretch_mode,
                  :miter_limit, :world_transform

    def dup
      other = DeviceContext.allocate
      other.pen = pen.dup
      other.brush = brush.dup
      other.font = font.dup
      other.text_color = text_color
      other.bk_color = bk_color
      other.bk_mode = bk_mode
      other.poly_fill_mode = poly_fill_mode
      other.map_mode = map_mode
      other.text_align = text_align
      other.stretch_mode = stretch_mode
      other.miter_limit = miter_limit
      other.world_transform = world_transform
      other
    end
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

    def initialize(style: SOLID, color: Emf::Model::Geometry::Color.white, hatch: 0)
      @style = style
      @color = color
      @hatch = hatch
    end

    attr_reader :style, :color, :hatch

    def self.default
      new
    end

    def null?
      style == NULL
    end

    def dup
      Brush.new(style: style, color: color, hatch: hatch)
    end
  end

  # Font value object: minimal subset of LOGFONT for text rendering.
  class Font
    DEFAULT_HEIGHT = 12

    def initialize(face_name: "sans-serif", height: DEFAULT_HEIGHT, weight: 400,
                   italic: false, underline: false, strikeout: false,
                   escapement: 0)
      @face_name = face_name
      @height = height
      @weight = weight
      @italic = italic
      @underline = underline
      @strikeout = strikeout
      @escapement = escapement
    end

    attr_reader :face_name, :height, :weight, :italic, :underline, :strikeout, :escapement

    def self.default
      new
    end

    def bold?
      weight >= 700
    end

    def dup
      Font.new(face_name: face_name, height: height, weight: weight,
               italic: italic, underline: underline, strikeout: strikeout,
               escapement: escapement)
    end
  end
end
