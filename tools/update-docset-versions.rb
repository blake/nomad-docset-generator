#!/usr/bin/env ruby
# frozen_string_literal: true

# This is a helper script which updates Nomad's 'docset.json' file in
# github.com/Kapeli/Dash-User-Contributions

require 'digest'
require 'fileutils'
require 'json'

NOMAD_DASH_USER_CONTRIBUTIONS_PATH = "#{ENV['DASH_USER_REPO']}/docsets/Nomad"

class DocsetVersion
  def initialize(archive:, version:)
    @archive = archive
    @version = version
  end

  attr_reader :version, :archive

  def sha1sum
    @sha1sum ||= read_sha1_sum_from_file
  end

  def as_json(_options = {})
    {
      version: @version,
      archive: @archive
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def read_sha1_sum_from_file
    sha_sum = nil
    archive_path = "#{NOMAD_DASH_USER_CONTRIBUTIONS_PATH}/#{archive}.txt"
    if File.exist?(archive_path)
      sha_line = File.open(archive_path).grep(/^SHA1:/)
      sha_sum = sha_line[0].match(/^SHA1: (\w+)$/).captures[0] if sha_line.size == 1
    end

    sha_sum
  end
end

class DocsetManifest
  attr_accessor :name, :aliases, :archive, :author, :version, :specific_versions

  def initialize(manifest)
    manifest.each do |key, value|
      public_send("#{key}=", value)
    end
    @specific_versions = @specific_versions.map do |sv|
      sv.transform_keys!(&:to_sym)
      DocsetVersion.new(**sv)
    end
  end

  def as_json(_options = {})
    obj_hash = {}
    instance_variables.each do |iv|
      key = iv.to_s.sub(/@/, '')
      obj_hash[key] = instance_variable_get(iv)
    end

    obj_hash
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end
end

docset_file_path = "#{NOMAD_DASH_USER_CONTRIBUTIONS_PATH}/docset.json"

if File.exist?(docset_file_path)
  docset_file = File.read(docset_file_path)
  docsets = DocsetManifest.new(JSON.parse(docset_file))
else
  docsets = DocsetManifest.new
end

built_docsets = Dir.glob('./build/v*/Nomad.tgz').map do |archive|
  { archive: archive, version: archive.sub(%r{^\./build/v(.+)/Nomad.tgz}, '\1') }
end

# Remove any beta or RC builds
built_docsets.reject! { |d| d[:version].match(/-\w+$/) }

built_docsets.each do |docset|
  # Get the sha1 sum of the docset we wish to add
  file_sha1sum = Digest::SHA1.file(docset[:archive]).hexdigest
  file_sha1shortsum = file_sha1sum[0...8]

  # Find each docset that matches this major verison string
  docset_version_list = docsets.specific_versions.dup.keep_if do |ds|
    ds.version.start_with?(docset[:version])
  end

  # Skip this file if the version matches a file that was previously uploaded
  existing_sha1sums = docset_version_list.map(&:sha1sum).compact
  next if existing_sha1sums.include?(file_sha1sum)

  # The uploaded file does not match what is in the CDN. Generate a new
  # version

  # Find how many other versions of this exist. We'll use a three digit
  # incrementing prefix to ensure that the newest version is always listed
  # first.
  sub_version_list = docset_version_list.map do |ds|
    matches = ds.version.match(%r{^[0-9.]+/(?<subversion>\d+{3})-(?<shortsha>\w+)$})
    if !matches
      nil
    else
      matches.named_captures
    end
  end.compact

  # The previous doc sets did not use this same formatting
  if docset_version_list.empty?
    latest_sub_version = 1
  elsif sub_version_list.empty?
    # There are existing records. If they don't use this same sub-version
    # format, start the number at plus one to the current size of the docset
    latest_sub_version = docset_version_list.size + 1
  else
    # Skip if the archive's short SHA already exists in the list of subverisons
    # written to the manifest.
    next if sub_version_list.map { |v| v['shortsha'] }.include?(file_sha1shortsum)

    # Previous versions have used this new format scheme. Find the most
    # recent version and increment by one
    sub_version_list.sort! { |a, b| b['subversion'] <=> a['subversion'] }
    latest_sub_version = sub_version_list[0].to_i + 1
  end

  archive_sub_version_string = "#{format('%03d', latest_sub_version)}-#{file_sha1shortsum}"
  archive_file = "#{docset[:version]}/#{archive_sub_version_string}/Nomad.tgz"
  new_version = {
    archive: "versions/#{archive_file}",
    version: "#{docset[:version]}/#{archive_sub_version_string}"
  }

  # Copy file to other repo
  version_dir = File.dirname("#{NOMAD_DASH_USER_CONTRIBUTIONS_PATH}/#{new_version[:archive]}")
  FileUtils.mkdir_p(version_dir) unless Dir.exist?(version_dir)

  FileUtils.cp(docset[:archive], "#{version_dir}/Nomad.tgz") unless File.exist?("#{version_dir}/Nomad.tgz")

  # Add version to docset
  docsets.specific_versions.push(DocsetVersion.new(**new_version))
end

docsets.specific_versions = docsets.specific_versions.sort do |a, b|
  b.version <=> a.version
end

# Grab latest version and add to header
docsets.version = docsets.specific_versions[0].version

# Write file back out to docset path
File.open(docset_file_path, 'w') do |f|
  f.write(JSON.pretty_generate(docsets, { 'indent': '    ' }))
end
