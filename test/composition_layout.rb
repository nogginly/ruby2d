require 'ruby2d'

set title: 'Hello Composable'

class CCircle
  include Composable

  def initialize(x, y, radius:, color:)
    @x = x - radius
    @y = y - radius
    @radius = radius
    @width = @height = radius * 2
    @color = color
  end

  def paint(context)
    context.fill_circle x: @radius, y: @radius, radius: @radius, color: @color
  end
end

class CRect
  include Composable

  def initialize(x, y, w, h, color:)
    @x = x
    @y = y
    @width = w
    @height = h
    @color = color
  end

  def paint(context)
    context.fill_rect x: 0, y: 0, width: @width, height: @height, color: @color
  end
end

class CText
  include Composable

  def initialize(x, y, text:, color:, size: 20, style: nil, font: Font.default)
    @x = x
    @y = y
    @text = text
    @texture = Text.create_texture(text, size: size, style: style, font: font)
    @width = @texture.width
    @height = @texture.height
    @color = color
  end

  def paint(context)
    context.draw_texture @texture, x: 0, y: 0, width: @width, height: @height, color: @color
  end
end

outer = LayoutComposition.new 10, 10, 320, 240, layout: GridLayout.new(rows: 3, columns: 3)
9.times do |i|
  if i.odd?
    outer.add CCircle.new(20, 20, radius: 20, color: 'green')
  else
    outer.add CText.new(0, 0, text: 'Hello', color: 'maroon', style: 'italics')
  end
end

outer.renderable.add

show
