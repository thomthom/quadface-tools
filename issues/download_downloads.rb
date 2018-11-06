require 'colorize'
require 'fileutils'
require 'net/http'
require 'json'
require 'uri'

DOWNLOADS_PATH = File.join(__dir__, 'downloads')

module Downloads

  def self.http_get(uri)
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPRedirection)
      uri = URI(response['location'])
      puts "> Redirected to #{uri} ..."
      response = Net::HTTP.get_response(uri)
    end

    unless response.is_a?(Net::HTTPSuccess)
      puts "HTTP #{response.code}".red
      puts JSON.pretty_generate(response.to_hash)
      puts response.body.red
      raise "unexpected error - HTTP #{response.code}"
    end

    response
  end

  def self.api_get(api_uri)
    raise unless api_uri.start_with?('/')
    uri = URI("https://api.bitbucket.org#{api_uri}")
    self.http_get(uri)
  end

  def self.fetch
    response = self.api_get('/2.0/repositories/thomthom/quadface-tools/downloads?pagelen=50')
    downloads = JSON.parse(response.body)
    # puts JSON.pretty_generate(downloads).yellow

    downloads_json = File.join(DOWNLOADS_PATH, 'downloads.json')
    FileUtils.mkdir_p(DOWNLOADS_PATH)
    File.write(downloads_json, JSON.pretty_generate(downloads))

    downloads['values'].each { |download|
      name = download['name']
      uri = URI(download['links']['self']['href'])

      puts "Downloading #{uri} ...".yellow
      file_path = File.join(DOWNLOADS_PATH, name)
      response = self.http_get(uri)
      File.binwrite(file_path, response.body)
      puts "> Downloaded to #{file_path}"
    }
  end

end

Downloads.fetch
