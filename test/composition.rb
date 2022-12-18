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

class BoxComposition < Composition
  def paint(context)
    context.fill_rect x: 0, y: 0, width: @width, height: @height, color: 'gray', opacity: 0.5
    super context
  end
end

inner = BoxComposition.new 50, 50, 60, 60
inner.add CCircle.new(20, 20, radius: 20, color: 'yellow')
inner.add CRect.new(20, 20, 30, 20, color: 'blue')
inner.add(itext = CText.new(0, 0, text: 'World', color: 'fuchsia'))

outer = BoxComposition.new 10, 10, 320, 240
outer.add CRect.new(20, 20, 30, 20, color: 'red')
outer.add inner
outer.add CCircle.new(20, 20, radius: 20, color: 'green')
outer.add(otext = CText.new(0, 0, text: 'Hello', color: 'maroon', style: 'italics'))

outer.renderable.add

puts 'Use arrow keys to move the outer composition.'
puts 'Use w, a, s, d keys to move the inner composition.'
puts 'Use h to toggle whether the inner composition is hidden or visble'
puts 'Use x to toggle removing/adding inner to outer composition'

on :key_held do |e|
  case e.key
  when 'a'
    inner.x -= 5
  when 'd'
    inner.x += 5
  when 'w'
    inner.y -= 5
  when 's'
    inner.y += 5
  when 'left'
    outer.x -= 5
  when 'right'
    outer.x += 5
  when 'up'
    outer.y -= 5
  when 'down'
    outer.y += 5
  end
end

def innards(component)
  puts component
  puts "  +-- parent: #{component.parent}"
end

on :key_down do |e|
  close if e.key == 'escape'

  case e.key
  when 'h'
    inner.hidden = !inner.hidden?
  when 'x'
    if inner.parent
      outer.remove inner
    else
      outer.add inner
    end
  when '/'
    innards(outer)
    innards(otext)
    innards(inner)
    innards(itext)
  end
end

show
