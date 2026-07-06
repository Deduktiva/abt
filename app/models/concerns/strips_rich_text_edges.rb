# Drops empty lines that Trix leaves at the start or end of a rich-text body,
# so preludes and boilerplate don't render stray blank lines on the PDF.
module StripsRichTextEdges
  extend ActiveSupport::Concern

  class_methods do
    def strips_rich_text_edges(*names)
      before_save do
        names.each do |name|
          rich = public_send(name)
          next if rich.nil? || rich.body.nil?

          html = rich.body.to_html
          stripped = StripsRichTextEdges.strip(html)
          rich.body = stripped if stripped != html
        end
      end
    end
  end

  def self.strip(html)
    fragment = Nokogiri::HTML5.fragment(html)
    trim_children(fragment.children)
    first = fragment.children.find(&:element?)
    trim_children(first.children) if first
    last = fragment.children.reverse.find(&:element?)
    trim_children(last.children) if last && last != first
    fragment.to_html
  end

  def self.trim_children(children)
    children.each { |node| blank_line?(node) ? node.remove : break }
    children.reverse.each { |node| blank_line?(node) ? node.remove : break }
  end

  def self.blank_line?(node)
    return true if node.text? && node.text.strip.empty?
    return true if node.element? && node.name == "br"
    node.element? && %w[div p].include?(node.name) &&
      node.text.strip.empty? && node.css("img, figure, action-text-attachment").empty?
  end
end
