require "erb"
require "nokogiri"
require "sqlite3"

# Nomad website URL
BASE_URL = 'https://nomadproject.io'

# Handles creation and insertion of data into the docset's index
class Index
  attr_accessor :db

  def initialize(path)
    @db = SQLite3::Database.new path
  end

  def drop
    @db.execute <<-SQL
      DROP TABLE IF EXISTS searchIndex
    SQL
  end

  def create
    # Create the docset index
    # https://kapeli.com/docsets#createsqlite
    db.execute <<-SQL
      CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)
    SQL
    db.execute <<-SQL
      CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)
    SQL
  end

  def reset
    drop
    create
  end

  def insert(type, path)
    # Insert records into the index
    # https://kapeli.com/docsets#fillsqlite
    doc = Nokogiri::HTML(File.open(path).read)
    name = doc.title.sub(" | Nomad by HashiCorp", "").sub(/.*: (.*)/, "\\1")
    @db.execute <<-SQL, name: name, type: type, path: path
      INSERT OR IGNORE INTO searchIndex (name, type, path)
      VALUES(:name, :type, :path)
    SQL
  end
end

task default: %i[clean setup copy create_index package]

task :clean do
  rm_rf "build"
  rm_rf "Nomad.docset"
end

task :setup do
  mkdir_p "Nomad.docset/Contents/Resources/Documents"

  # Docset icon
  if File.exist?("out/img/favicons/favicon-16x16.png") &&
     File.exist?("out/img/favicons/favicon-32x32.png")
    FileUtils.cp("out/img/favicons/favicon-16x16.png",
                 "Nomad.docset/icon.png")
    FileUtils.cp("out/img/favicons/favicon-32x32.png",
                 "Nomad.docset/icon@2x.png")
  elsif File.exist? "ui/public/favicon.png"
    cp "ui/public/favicon.png", "Nomad.docset/icon.png"
  end

  # Create Info.plist
  # https://kapeli.com/docsets#infoplist
  File.open("Nomad.docset/Contents/Info.plist", "w") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>nomad</string>
          <key>CFBundleName</key>
          <string>Nomad</string>
          <key>DocSetPlatformFamily</key>
          <string>nomad</string>
          <key>isDashDocset</key>
          <true/>
          <key>DashDocSetFamily</key>
          <string>dashtoc</string>
          <key>dashIndexFilePath</key>
          <string>docs/index.html</string>
          <key>DashDocSetFallbackURL</key>
          <string>#{BASE_URL}</string>
        </dict>
      </plist>
    XML
  end
end

task :copy do
  file_list = []
  Dir.chdir("out") { file_list = Dir.glob("**/*").sort }

  file_list.each do |path|
    source = "out/#{path}"
    target = "Nomad.docset/Contents/Resources/Documents/#{path}"

    # Determine relative path of current file
    source_path = URI.parse(BASE_URL + source.delete_prefix('out'))

    if File.stat(source).directory?
      mkdir_p target
    elsif source.end_with?(".gz")
      next
    elsif source.end_with?(".html")
      doc = Nokogiri::HTML(File.open(source).read)

      # Remove following from document titles
      doc.title = doc.title.sub(" | Nomad by HashiCorp", "")
      doc.title = doc.title.sub(" - HTTP API", "")

      # Find section headings within document
      doc.xpath("//a[contains(@class, '__target-h')]").each do |e|
        a = Nokogiri::XML::Node.new "a", doc

        # Remove '»' permalink
        e.previous.remove if e.previous.text == '»'

        # Obtain section name from element following anchor tag
        next_sibling = e.next_sibling

        section_name = next_sibling.text.strip

        # If first part of header is in a code block, grab the following text
        # as well
        if next_sibling.name == "code"
          section_name += next_sibling.next_sibling&.text.to_s
        end

        # Skip headings with the same name as the document title
        next if section_name == doc.title || section_name.empty?

        # Add dashAnchor links to generate per-page Table of Contents
        # https://kapeli.com/docsets#tableofcontents
        a["class"] = "dashAnchor"
        a["name"] = format(
          "//apple_ref/cpp/%<type>s/%<name>s",
          # TODO: Modify type based on content being indexed
          # https://kapeli.com/docsets#supportedentrytypes
          type: "Section",
          name: ERB::Util.url_encode(section_name)
        )
        e.previous = a
      end

      # Remove JavaScript tags on all documentation pages
      doc.xpath('//script').each do |script|
        script.remove if script.text != ""
      end

      # Find all links on page
      doc.xpath('//link').each do |link|

        # If the link is relative
        if link.attributes.has_key?("href") and link.attributes["href"].value.start_with?('/')

          # Remove CORS settings on link
          link.remove_attribute("crossorigin")

          # Do not preload content. Load it synchronously.
          if link.attributes["rel"].value == "preload"

            as_value = link.attributes["as"].value

            if as_value == "style"
              link.attributes["rel"].value = "stylesheet"
            elsif as_value == "script"
              link.attributes["rel"].value = "script"
            end

            link.remove_attribute("as")
          end

          # Ensure script/stylesheet location is relative to the current file
          link_href = BASE_URL + link.attributes["href"].value
          link.attributes["href"].value = source_path.route_to(link_href).to_s
        end
      end

      # Remove the following elements from doc pages
      doc.xpath("id('header')").each(&:remove)
      doc.xpath("//div[contains(@class, 'g-alert-banner')]").each(&:remove)
      doc.xpath("//div[contains(@class, 'g-mega-nav')]").each(&:remove)
      doc.xpath("//div[contains(@class, 'g-subnav')]").each(&:remove)
      doc.xpath("id('sidebar')").each(&:remove)
      doc.xpath("id('edit-this-page')").each(&:remove)
      doc.xpath("//footer[contains(@class, 'g-footer')]").each(&:remove)

      # Remove margin on headings
      doc.xpath('//div[@id="inner"]/*/h2').each do |e|
        e["style"] = "margin-top: 0px"
      end

      # Fix links to other documents
      doc.xpath('//div[@id="inner"]//a').each do |e|

        # Skip anchor if it does not have an href attribute
        next unless e.attributes.has_key?("href")

        anchor = e.attributes["href"]

        # If the href is relative
        if anchor.value =~ /^\/\w+/

          parsed_uri = URI.parse(BASE_URL + anchor.value)

          # Modify URI paths which references directories to point to the
          # actual index.html file
          unless parsed_uri.path.end_with?('index.html')
            parsed_uri.path = parsed_uri.path + '/index.html'

            # Convert nomadproject.io URLs to relative URLs
            if parsed_uri.host == "nomadproject.io"
              anchor.value = source_path.route_to(parsed_uri).to_s
            end

          end
        end
      end

      # Set width of documentation content to 100%
      doc.xpath("//div[contains(@role, 'main')]").each do |e|
        e["style"] = "width: 100%"
      end

      # Write resultant file to Nomad.docset/ path
      File.open(target, "w") { |f| f.write doc }
    else
      # If the file does not end .html, it must be an image or other asset
      # Copy it directly into the target directory
      cp source, target
    end
  end
end

task :create_index do
  index = Index.new("Nomad.docset/Contents/Resources/docSet.dsidx")
  index.reset

  Dir.chdir("Nomad.docset/Contents/Resources/Documents") do
    # api
    Dir.glob("api-docs/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Define", path
    end
    # docs
    Dir.glob("docs/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Guide", path
    end
    # docs/commands
    Dir.glob("docs/commands/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Command", path
    end
    # docs/configuration
    Dir.glob("docs/configuration/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Setting", path
    end
    # docs/devices
    Dir.glob("docs/devices/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Setting", path
    end
    # docs/drivers
    Dir.glob("docs/drivers/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Setting", path
    end
    # docs/enterprise
    Dir.glob("docs/enterprise/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Environment", path
    end
    # docs/internals
    Dir.glob("docs/internals/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Instruction", path
    end
    # docs/job-specification
    Dir.glob("docs/job-specification/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Setting", path
    end
    # docs/runtime
    Dir.glob("docs/runtime/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Environment", path
    end
    # docs/telemetry
    Dir.glob("docs/telemetry/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Setting", path
    end
    # docs/vault-integration
    Dir.glob("docs/vault-integration/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Setting", path
    end
    # docs/integrations/
    Dir.glob("docs/integrations/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Guide", path
    end
    # getting-started
    Dir.glob("intro/getting-started/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Guide", path if path.end_with?(".html")
    end
    # vs
    Dir.glob("intro/vs/**/*")
       .find_all { |f| File.stat(f).file? }.each do |path|
      index.insert "Guide", path if path.end_with?(".html")
    end
  end
end

task :package do
  sh "tar --exclude='.DS_Store' -cvzf Nomad.tgz Nomad.docset"
end
