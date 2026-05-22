class Attachment < ApplicationRecord
  MAX_SIZE_BYTES = 25.megabytes
  SAFE_CONTENT_TYPES = %w[application/pdf image/png image/jpeg].freeze
  DEFAULT_CONTENT_TYPE = 'application/octet-stream'.freeze

  validates :title, presence: true
  validate :data_size_within_limit
  validate :content_type_in_safelist

  def uploaded_file=(incoming_file)
    self.filename = incoming_file.original_filename
    self.content_type = incoming_file.content_type
    self.data = incoming_file.read
  end

  def set_data(data, content_type)
    self.data = data
    self.content_type = content_type
  end

  def filename=(new_filename)
    write_attribute("filename", sanitize_filename(new_filename))
  end

  # Returns a safelisted content type, or octet-stream for unknown values.
  # Used when serving attachment data to neuter XSS via a crafted Content-Type.
  def safe_content_type
    SAFE_CONTENT_TYPES.include?(content_type) ? content_type : DEFAULT_CONTENT_TYPE
  end

  private

  def sanitize_filename(filename)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(filename)
    # replace all non-alphanumeric, underscore or periods with underscores
    just_filename.gsub(/[^\w\.\-]/, '_')
  end

  def data_size_within_limit
    return if data.blank?
    if data.bytesize > MAX_SIZE_BYTES
      errors.add(:data, "is too large (maximum is #{MAX_SIZE_BYTES / 1.megabyte} MB)")
    end
  end

  def content_type_in_safelist
    return if content_type.blank?
    unless SAFE_CONTENT_TYPES.include?(content_type)
      errors.add(:content_type, "must be one of: #{SAFE_CONTENT_TYPES.join(', ')}")
    end
  end
end
