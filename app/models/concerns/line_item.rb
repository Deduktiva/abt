module LineItem
  extend ActiveSupport::Concern

  TYPE_OPTIONS = {
    "Text" => "text",
    "Item" => "item",
    "Subheading" => "subheading",
    "Plaintext" => "plain"
  }.freeze

  included do
    validates :title, presence: true
    validates :type, presence: true, inclusion: TYPE_OPTIONS.values

    def self.inheritance_column
      "type_"
    end
  end

  def is_item?
    self[:type] == "item"
  end
end
