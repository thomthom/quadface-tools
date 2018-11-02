require 'fileutils'
require 'net/http'
require 'json'
require 'uri'

archive_path = File.join(__dir__, 'quadface-tools-issues')

db_filename = File.join(archive_path, 'db-1.0.json')
db = JSON.parse(File.read(db_filename))

URL_REGEX = /https:[^ \n\r]+/
EMBEDDED_URLS_REGEX = %r{https://bitbucket.org/repo/[^ \n\r)]+}

urls = []

%w(issues comments).each { |type|
  items = db[type]
  items.each { |item|
    content = item['content']
    next if content.nil?
    content_urls = content.scan(EMBEDDED_URLS_REGEX)
    urls.concat(content_urls)
    next if content_urls.empty?
    title = item['title'] || "Issue #{item['issue']}"
    puts "#{type[0..-2]} : #{title}"
    puts content_urls.join("\n")
  }
}

# puts urls.join("\n")

embedded_path = File.join(__dir__, 'embedded')
FileUtils.mkdir_p(embedded_path)
urls.each { |url|
  uri = URI(url)
  filename = File.basename(uri.path)
  file_path = File.join(embedded_path, filename)
  puts "Downloading #{url} to #{file_path} ..."

  response = Net::HTTP.get_response(uri)
  if response.is_a?(Net::HTTPRedirection)
    uri = URI(response['location'])
    puts "> Redirected to #{url} ..."
    response = Net::HTTP.get_response(uri)
  end

  unless response.is_a?(Net::HTTPSuccess)
    puts "HTTP #{response.code}"
    puts JSON.pretty_generate(response.to_hash)
    puts response.body
    raise "unexpected error - HTTP #{response.code}"
  end

  # puts JSON.pretty_generate(response.to_hash)

  File.binwrite(file_path, response.body)
}
