require "builder"
require "nokogiri"

# Translates the ActionText/Trix HTML subset we allow (bold, italic, h1,
# bullet/numbered lists, paragraphs) into an XSL-FO fragment. Text is emitted
# via Builder::XmlMarkup so it is auto-escaped, keeping the single safe
# XML-construction path documented in FopRenderer. Unknown elements are dropped
# but their text content is preserved. Soft line breaks (<br>) become U+2028,
# which FOP treats as a forced line break.
class RichTextFoConverter
  LINE_SEPARATOR = " "

  def initialize(html)
    @html = html.to_s
  end

  def to_fo_fragment
    nodes = Nokogiri::HTML5.fragment(@html).children
    xml = Builder::XmlMarkup.new
    nodes.each { |node| render_block(node, xml) }
    xml.target!
  end

  private

  def render_block(node, xml)
    case node.name
    when "ul", "ol"
      render_list(node, xml)
    when "h1"
      xml.tag!("fo:block", "font-size" => "14pt", "font-weight" => "bold",
               "space-before" => "6pt", "space-after" => "4pt") do |b|
        render_inline(node.children, b)
      end
    when "div", "p"
      xml.tag!("fo:block") { |b| render_inline(node.children, b) }
    when "text"
      xml.tag!("fo:block") { |b| render_inline([ node ], b) } unless node.text.strip.empty?
    else
      xml.tag!("fo:block") { |b| render_inline(node.children, b) } if node.element?
    end
  end

  def render_list(node, xml)
    items = build_items(node)
    xml.tag!("fo:list-block", "provisional-distance-between-starts" => "5mm",
             "provisional-label-separation" => "2mm", "space-after" => "4pt") do |lb|
      items.each_with_index do |item, index|
        label = node.name == "ol" ? "#{index + 1}." : "•"
        lb.tag!("fo:list-item") do |list_item|
          list_item.tag!("fo:list-item-label", "end-indent" => "label-end()") do |l|
            l.tag!("fo:block") { |b| b.text!(label) }
          end
          list_item.tag!("fo:list-item-body", "start-indent" => "body-start()") do |body|
            body.tag!("fo:block") { |b| render_inline(item[:inline], b) }
            item[:sublists].each { |sublist| render_list(sublist, body) }
          end
        end
      end
    end
  end

  # Group a list's children into items, each carrying its inline content and any
  # nested <ul>/<ol> sublists. Trix nests as a sublist inside the <li>
  # (child-of-li form); a sublist appearing as a sibling of the <li> is attached
  # to the preceding item so it renders as that item's indented sub-list.
  def build_items(node)
    items = []
    node.children.each do |child|
      if child.name == "li"
        inline = child.children.reject { |c| c.name == "ul" || c.name == "ol" }
        sublists = child.children.select { |c| c.name == "ul" || c.name == "ol" }
        items << { inline: inline, sublists: sublists }
      elsif child.name == "ul" || child.name == "ol"
        (items.last || (items << { inline: [], sublists: [] }).last)[:sublists] << child
      end
    end
    items
  end

  def render_inline(nodes, xml)
    nodes.each do |node|
      case node.name
      when "text"
        xml.text!(node.text)
      when "strong", "b"
        xml.tag!("fo:inline", "font-weight" => "bold") { |i| render_inline(node.children, i) }
      when "em", "i"
        xml.tag!("fo:inline", "font-style" => "italic") { |i| render_inline(node.children, i) }
      when "br"
        xml.text!(LINE_SEPARATOR)
      else
        render_inline(node.children, xml)
      end
    end
  end
end
