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
  def parse_docset(docset)
    matches = docset.match(%r{\w+/v(?<version>[0-9.]+)/(?<filename>\w+.tgz)$})
    return unless matches

    verison_string = matches[:version]
    file_path = "#{verison_string}/#{matches[:filename]}"

    {
      version: verison_string,
      url: "http://localhost:#{@http_port}/#{file_path}"
    }
  end

  def initialize(directory:, port:)
    @builder = Nokogiri::XML::Builder.new do |xml|
      xml.send('entry'.to_sym)
    end

    @http_port = port.to_s

    docsets = Dir.glob("#{directory}/*/*.tgz").sort.reverse

    first_docset = parse_docset(docsets[0])
    main_version = Nokogiri::XML::Node.new('version', @builder.doc)
    main_version.content = first_docset[:version]
    @builder.doc.at_xpath('/entry').add_child main_version

    main_url = Nokogiri::XML::Node.new('url', @builder.doc)
    main_url.content = first_docset[:url]
    @builder.doc.at_xpath('/entry').add_child main_url

    return unless docset.size > 1

    other_versions = Nokogiri::XML::Node.new('other-versions', @builder.doc)
    @builder.doc.at_xpath('/entry').add_child other_versions

    docsets.each do |docset|
      docset = parse_docset(docset)

      next unless docset.is_a? Hash

      version_element = Nokogiri::XML::Node.new('version', @builder.doc)

      # Add <name> element
      version_name = Nokogiri::XML::Node.new('name', @builder.doc)
      version_name.content = docset[:version]
      version_element.add_child version_name

      # Add <url> element
      version_url = Nokogiri::XML::Node.new('url', @builder.doc)
      version_url.content = docset[:url]
      version_element.add_child version_url

      other_versions.add_child version_element
    end
  end

  def to_s
    @builder.to_xml
  end
end

http_port = 8000
root_directory = File.expand_path 'build'
feed_name = 'Nomad.xml'

feed = DocsetFeed.new(directory: root_directory, port: http_port)

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
