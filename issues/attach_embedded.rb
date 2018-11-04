require 'colorize'
require 'digest'
require 'fileutils'
require 'json'
require 'uri'

# https://confluence.atlassian.com/bitbucket/export-or-import-issue-data-330797432.html
# https://confluence.atlassian.com/bitbucket/issue-import-export-data-format-330796872.html

URL_REGEX = /https:[^ \n\r]+/
EMBEDDED_URLS_REGEX = %r{https://bitbucket.org/repo/[^ \n\r)]+}
EMBEDDED_IMAGE_REGEX = %r{!\[([^\]]+)\]\((https:\/\/bitbucket.org\/repo\/[^ \n\r)]+)\)}
IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif]

ARCHIVE_PATH = File.join(__dir__, 'quadface-tools-issues').freeze
PATCHED_PATH = File.join(__dir__, 'patched', 'quadface-tools-issues')
EMBEDDED_PATH = File.join(__dir__, 'embedded').freeze

SOURCE_ATTACHEMENTS = File.join(ARCHIVE_PATH, 'attachments').freeze
TARGET_ATTACHEMENTS = File.join(PATCHED_PATH, 'attachments').freeze

Attachment = Struct.new(:path, :issue, :user, :filename)


module Issues

  # @param [Integer] issue_id
  # @param [String] user The BitBucket username
  # @param [String] content The content string. Will be modified if it contains
  #                         embedded images from BitBucket.
  # @return [Array<Attachment>]
  def self.embedded_images_to_attachments(issue_id, user, content)
    return [] if content.nil?
    content_urls = content.scan(EMBEDDED_URLS_REGEX)

    embedded_images = content.scan(EMBEDDED_IMAGE_REGEX)
    unless embedded_images.size == content_urls.size
      puts "More embedded URLs than embedded image codes #{content_urls.size} vs #{embedded_images.size}".red
      exit 1
    end
    return [] if embedded_images.empty?

    attachments = []
    embedded_images.each { |filename, url|
      puts "Issue #{issue_id}: #{filename} - #{url}".yellow
      next unless IMAGE_EXTENSIONS.include?(File.extname(url))
      puts "> Converting embedded image to attached image..."

      # Decode the URI into a normal filename.
      embedded_filename = File.basename(url)
      encoded_filename = embedded_filename.match(/\d+\-(.*)/).captures.first
      filename = URI.decode(encoded_filename)

      # Generate a hash similar to BitBucket. Use the original embedded filename
      # as it includes a hash-prefix that should ensure this hash stays unique.
      filename_hash = Digest::MD5.hexdigest(embedded_filename)

      # Now we have all the data for creating a new attachment.
      path = File.join('attachments', filename_hash)
      attachment = Attachment.new(path, issue_id, user, filename)
      # puts JSON.pretty_generate(attachment.to_h)

      # Copy embedded image to attachments directory.
      source = File.join(EMBEDDED_PATH, embedded_filename)
      target = File.join(TARGET_ATTACHEMENTS, filename_hash)
      FileUtils.copy(source, target, verbose: false)

      # Convert original URI to attachment reference.
      embed_code = "![#{filename}](#{url})"
      replacement = "(See attachment: #{filename})"
      if content.gsub!(embed_code, replacement).nil?
        warn "WARN: Unable to replace #{filename}".red
      end

      attachments << attachment
    }
    attachments
  end

end # module


# Load JSON database
db_filename = File.join(ARCHIVE_PATH, 'db-1.0.json')
db = JSON.parse(File.read(db_filename))

existing_attachments = db['attachments'].size

# Convert embedded images in issues into attachments.
puts 'Processing issues...'.blue
db['issues'].each { |issue|
  issue_id = issue['id']
  user = issue['reporter']
  content = issue['content']

  attachments = Issues.embedded_images_to_attachments(issue_id, user, content)

  db['attachments'].concat(attachments.map(&:to_h))
}

# Convert embedded images in comment into attachments.
puts 'Processing issue comments...'.blue
db['comments'].each { |comment|
  issue_id = comment['issue']
  user = comment['user']
  content = comment['content']

  attachments = Issues.embedded_images_to_attachments(issue_id, user, content)

  db['attachments'].concat(attachments.map(&:to_h))
}

# Ensure the target directory for patched issues exists.
FileUtils.mkdir_p(PATCHED_PATH)

# Write out the patched database.
json = JSON.pretty_generate(db)
patched_db_filename = File.join(PATCHED_PATH, 'db-1.0.json')
File.write(patched_db_filename, json)

# Copy over all attachments.
FileUtils.mkdir_p(TARGET_ATTACHEMENTS, verbose: true)
FileUtils.copy_entry(SOURCE_ATTACHEMENTS, TARGET_ATTACHEMENTS, verbose: true)
