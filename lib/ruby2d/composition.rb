# frozen_string_literal: true

module Ruby2D
  # Drawing context
  class PaintContext
    attr_reader :origin_x, :origin_y

    def initialize(paintable: nil, x: nil, y: nil)
      if paintable.nil?
        @origin_x = x || 0
        @origin_y = y || 0
      else
        @origin_x = paintable.x
        @origin_y = paintable.y
      end
    end

    def fill_rect(x:, y:, width:, height:, color: 'white', colour: nil, opacity: nil)
      c = Color.new(color || colour)
      c.opacity = opacity unless opacity.nil?
      c = c.to_a
      Rectangle.draw x: x + @origin_x, y: y + @origin_y,
                     width: width, height: height, color: [c, c, c, c]
    end

    def fill_circle(x:, y:, radius:, sectors: 30, color: 'white', colour: nil, opacity: nil)
      c = Color.new(color || colour)
      c.opacity = opacity unless opacity.nil?
      Circle.draw x: x + @origin_x, y: y + @origin_y,
                  radius: radius, sectors: sectors, color: c.to_a
    end

    def draw_texture(texture, x:, y:, width: nil, height: nil, rotate: 0, color: 'white', colour: nil, opacity: nil)
      c = Color.new(color || colour)
      c.opacity = opacity unless opacity.nil?
      verts = Vertices.new(x + @origin_x, y + @origin_y,
                           width || texture.width, height || texture.height, rotate)
      texture.draw verts.coordinates, verts.texture_coordinates, c
    end

    def set_origin(x, y)
      @origin_x += x
      @origin_y += y
    end
  end

  # Base class for all paintable components
  module Paintable
    attr_reader :x, :y, :width, :height

    # Implement to paint
    # @param context [PaintContext] Drawing context with utilities to draw shapes and textures
    def paint(context); end
  end

  module Composable
    include Paintable

    attr_reader :hidden, :parent

    alias hidden? hidden

    def initialize
      @parent = nil
    end

    def relocate(x, y)
      @x = x
      @y = y
    end

    def resize(width, height)
      @width = width
      @height = height
    end

    protected

    def parent=(composable)
      raise TypeError, 'parent must be `Composable`' unless composable.nil? || composable.is_a?(Composable)

      @parent = composable
    end
  end

  # @visibility private do not document
  # Used to wrap a +Composition+ as a +Renderable+ added to a Window
  class CompositionRenderer
    include Renderable

    def initialize(composition)
      @composition = composition
      @z = nil
    end

    def x
      @composition.x
    end

    def x=(value)
      @composition.x = value
    end

    def y
      @composition.y
    end

    def y=(value)
      @composition.y = value
    end

    def width
      @composition.width
    end

    def width=(value)
      @composition.resize(value, height)
    end

    def height
      @composition.height
    end

    def height=(value)
      @composition.resize(width, value)
    end

    private

    def render
      @composition.paint PaintContext.new(paintable: @composition)
    end
  end

  class Composition
    include Composable

    attr_accessor :x, :y, :hidden

    # Create a composition container
    # @param x [Numeric]
    # @param y [Numeric]
    # @param width [Numeric]
    # @param height [Numeric]
    # param hidden [true, false] A hidden composable is not painted; default is +false+
    def initialize(x, y, width, height, hidden: false)
      @x = x
      @y = y
      @width = width
      @height = height
      @components = []
      @renderable = nil
      @hidden = hidden
    end

    def count
      @components.count
    end

    # Add a +Composable+ component into the container
    # @param component [Composable]
    # @raise [TypeError] if +component+ isn't the right type
    # @raise [ArgumentError] if +component+ is already in the container
    def add(component)
      raise TypeError, '`component` must be `Ruby2D::Composable`' unless component.is_a? Composable
      raise ArgumentError, '`paintable` already in the container`' if component.parent == self
      raise ArgumentError, '`paintable` already in another container`' unless component.parent.nil?

      @components.push component
      component.parent = self
    end

    # Remove a previously added +Composable+ component from the container
    # @param component [Composable] Must have previously been added to this container
    # @raise [TypeError] if +component+ isn't the right type
    # @raise [ArgumentError] if +component+ is not in the container
    def remove(component)
      raise TypeError, '`component` must be `Ruby2D::Composable`' unless component.is_a? Composable
      raise ArgumentError, '`component` not in this container`' unless component.parent == self

      ix = @components.index(component)
      raise ArgumentError, '`component` claims this as parent but not found in list' if ix.nil?

      @components.delete_at(ix)
      component.parent = nil
    end

    # Implement to paint
    # @param context [PaintContext] Drawing context with utilities to draw shapes and textures
    def paint(context)
      @components.each do |p|
        next if p.hidden?

        context.set_origin p.x, p.y
        p.paint context
        context.set_origin(-p.x, -p.y)
      end
    end

    # Obtain a +Renderable+ singleton for this composition that can be added to +Window+. Caller must add
    # it to the Window.
    def renderable
      @renderable ||= CompositionRenderer.new(self)
    end
  end

  module LayoutManager
    def initialize
      @invalidated = true
    end

    # Called by the +LayoutComposition+ that this layout manager is associated with to pass along any
    # layout constraints supplied when the component is added to the composition. Invalidates the layout.
    # @param component [Composable]
    def add(_component, _constraint)
      invalidate
    end

    # Called by the +LayoutComposition+ that this layout manager is associated with to let the layout
    # manager that a component has been removed from the composition. Invalidates the layout.
    # @param component [Composable]
    def remove(_component)
      invalidate
    end

    # Call the request a re-layout.
    def invalidate
      @invalidated = true
    end

    # Return +true+ if a re-layout is pending
    # @return [true, false]
    def invalidated?
      @invalidated
    end

    # Called by the +LayoutComposition+ that this layout manager is associated with to ask the layout
    # manager know to layout the components based on the constraints if the layout has been previously
    # invalidated. This is called every time the composition is painted, so it should only
    # recalculate layout if absolutely required.
    #
    # @param container [LayoutComposition] Composition that owns this layout manager; will not modify.
    # @param components [Array<Composable>] The container's components to lay out.
    def layout(container, components); end
  end

  class GridLayout
    include LayoutManager

    attr_reader :rows, :columns

    def initialize(rows:, columns:)
      @rows = rows
      @columns = columns
    end

    def layout(container, components)
      return unless invalidated?

      cellw = container.width / @columns
      cellh = container.height / @rows
      components.each_with_index do |c, i|
        cellx = i % @columns
        celly = i / @columns
        c.relocate(cellx * cellw, celly * cellh)
        c.resize(cellw, cellh)
      end
    end
  end

  class LayoutComposition < Composition
    # Create a composition container that can use a layout manager
    # @param x [Numeric]
    # @param y [Numeric]
    # @param width [Numeric]
    # @param height [Numeric]
    # param hidden [true, false] A hidden composable is not painted; default is +false+
    # param layout [LayoutManager] Supply an optional layout manager
    def initialize(x, y, width, height, hidden: false, layout: nil)
      unless layout.nil? || layout.is_a?(LayoutManager)
        raise ArgumentError,
              'layout must implement `LayoutManager`'
      end
      @layout_manager = layout
      super x, y, width, height, hidden: hidden
    end

    def resize(width, height)
      super(width, height)
      @layout_manager&.invalidate
    end

    # Add a +Composable+ component into the container
    # @param component [Composable]
    # @param layout_constraint A constraint specific to the layout manager if one is associated.
    # @raise [TypeError] if +component+ isn't the right type
    # @raise [ArgumentError] if +component+ is already in the container
    def add(component, layout_constraint = nil)
      super component
      @layout_manager&.add(component, layout_constraint)
    end

    # Remove a previously added +Composable+ component from the container
    # @param component [Composable] Must have previously been added to this container
    # @raise [TypeError] if +component+ isn't the right type
    # @raise [ArgumentError] if +component+ is not in the container
    def remove(component)
      super component
      @layout_manager&.remove(component)
    end

    # Implement to paint
    # @param context [PaintContext] Drawing context with utilities to draw shapes and textures
    def paint(context)
      @layout_manager.layout(self, @components) if @layout_manager&.invalidated?
      super context
    end
  end
end
