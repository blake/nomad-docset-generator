#!/usr/bin/env ruby
# frozen_string_literal: true

# This script starts a web server which serves a Dash doc feed at
# http://localhost:<port>/Nomad.xml.
#
# The purpose is to allow rapid testing of locally generated docsets prior to
# uploading them to the Dash CDN.

require 'cgi'
require 'nokogiri'
require 'webrick'

# Models a Dash doc feed as described in https://kapeli.com/docsets#dashdocsetfeed
class DocsetFeed
  attr_reader :name

  def initialize(name:, directory:, port:)
    @builder = Nokogiri::XML::Builder.new do |xml|
      xml.send('entry'.to_sym)
    end

    @http_port = port.to_s
    @name = name

    @docsets = []
    Dir.glob("#{directory}/*/*.tgz").sort.reverse.each do |f|
      docset = parse_filename(f)
      @docsets.push docset unless docset.nil?
    end

    generate_feed
  end

  def parse_filename(docset)
    matches = docset.match(%r{\w+/v(?<version>[0-9.]+)/(?<filename>\w+.tgz)$})
    return unless matches

    { version: matches[:version] }
  end

  def build_version_element(version:, url: nil)
    version_element = Nokogiri::XML::Node.new('version', @builder.doc)

    # Add <name> element
    version_name = Nokogiri::XML::Node.new('name', @builder.doc)
    version_name.content = version
    version_element.add_child version_name

    # Add <url> element if exists
    if url
      version_url = Nokogiri::XML::Node.new('url', @builder.doc)
      version_url.content = docset[:url]
      version_element.add_child version_url
    end

    version_element
  end

  def generate_feed
    return if @docsets.empty?

    first_docset = @docsets[0]
    main_version = Nokogiri::XML::Node.new('version', @builder.doc)
    main_version.content = first_docset[:version]
    @builder.doc.at_xpath('/entry').add_child main_version

    main_version = first_docset.key?(:url) ? first_docset[:url] : "http://localhost:#{@http_port}/Nomad.tgz"

    main_url = Nokogiri::XML::Node.new('url', @builder.doc)
    main_url.content = main_version
    @builder.doc.at_xpath('/entry').add_child main_url

    # Add other versions of present
    return unless @docsets.size > 1

    other_versions = Nokogiri::XML::Node.new('other-versions', @builder.doc)
    @builder.doc.at_xpath('/entry').add_child other_versions

    @docsets.each do |docset|
      other_versions.add_child build_version_element(version: docset[:version])
    end
  end

  def to_s
    @builder.to_xml
  end
end

http_port = 8000
root_directory = File.expand_path 'build'
docset_name = 'Nomad'
feed_name = "#{docset_name}.xml"

feed = DocsetFeed.new(name: docset_name, directory: root_directory, port: http_port)

server = WEBrick::HTTPServer.new Port: http_port

# Serve docset archives from /assets folder
server.mount('/assets', WEBrick::HTTPServlet::FileHandler,
             root_directory)

#  Handle requests for Nomad.xml
server.mount_proc "/#{feed_name}" do |_req, res|
  res.body = feed.to_s
end

# Serve a generic index page
server.mount_proc '/index.html' do |_req, res|
  encoded_feed = CGI.escape "http://localhost:#{server.config[:Port]}/#{feed_name}"
  response = <<-INDEX_PAGE
  <a href="/#{feed_name}">Dash feed - #{feed_name}</a><br>
  <a href="dash-feed://#{encoded_feed}">Click me to add to Dash</a>
  INDEX_PAGE
  res.body = response
end

# Default handler for all other requests
server.mount_proc '/' do |req, res|
  if req.path == '/'
    res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, '/index.html')
  else

    matches = req.path.match(%r{(?<version>[0-9.]+)/(?<filename>\w+\.tgz$)})

    if matches
      # If we understand the URL format, issue an HTTP redirect to the location
      # where it can be downloaded
      new_url = "/assets/v#{matches[:version]}/#{matches[:filename]}"
      res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, new_url)
    else
      # Otherwise, return 404 for the request
      res.status = 404
    end
  end
end

trap 'INT' do
  server.shutdown
end

server.start
