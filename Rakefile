require "erb"
require "nokogiri"
require "sqlite3"

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
    doc = Nokogiri::HTML(File.open(path).read)
    name = doc.title.sub(" - Nomad by HashiCorp", "").sub(/.*: (.*)/, "\\1")
    @db.execute <<-SQL, name: name, type: type, path: path
      INSERT OR IGNORE INTO searchIndex (name, type, path)
      VALUES(:name, :type, :path)
    SQL
  end
end

task default: %i[clean build setup copy create_index package]

task :clean do
  rm_rf "build"
  rm_rf "Nomad.docset"
end

task :build do
  config_extensions = ["activate :relative_assets", "set :relative_links, true",
                       "set :strip_index_file, false"]
  File.open("config.rb", "a") do |f|
    config_extensions.each do |ce|
      f.puts ce if File.readlines("config.rb").grep(Regexp.new(ce)).size.zero?
    end
  end

  sh "bundle"
  sh "bundle exec middleman build"
end

task :setup do
  mkdir_p "Nomad.docset/Contents/Resources/Documents"

  # Icon
  # at older docs there is no retina icon
  if File.exist?("source/assets/images/favicons/favicon-16x16.png") &&
     File.exist?("source/assets/images/favicons/favicon-32x32.png")
    FileUtils.cp("source/assets/images/favicons/favicon-16x16.png",
                 "Nomad.docset/icon.png")
    FileUtils.cp("source/assets/images/favicons/favicon-32x32.png",
                 "Nomad.docset/icon@2x.png")
  elsif File.exist? "source/assets/images/favicon.png"
    cp "source/assets/images/favicon.png", "Nomad.docset/icon.png"
  else
    cp "source/images/favicon.png", "Nomad.docset/icon.png"
  end

  # Info.plist
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
          <string>https://www.nomadproject.io/</string>
          </dict>
      </plist>
    XML
  end
end

task :copy do
  file_list = []
  Dir.chdir("build") { file_list = Dir.glob("**/*").sort }

  file_list.each do |path|
    source = "build/#{path}"
    target = "Nomad.docset/Contents/Resources/Documents/#{path}"

    if File.stat(source).directory?
      mkdir_p target
    elsif source.end_with?(".gz")
      next
    elsif source.end_with?(".html")
      doc = Nokogiri::HTML(File.open(source).read)

      doc.title = doc.title.sub(" - Nomad by HashiCorp", "")
      doc.title = doc.title.sub(" - HTTP API", "")

      doc.xpath("//a[contains(@class, 'anchor')]").each do |e|
        a = Nokogiri::XML::Node.new "a", doc

        section_name = e.next_sibling.text.strip

        # Skip headings with the same name as the document title
        next if section_name == doc.title || section_name.empty?

        a["class"] = "dashAnchor"
        a["name"] = format(
          "//apple_ref/cpp/%<type>s/%<name>s",
          type: "Section",
          name: ERB::Util.url_encode(section_name)
        )
        e.previous = a
      end

      doc.xpath('//script').each do |script|
        script.remove if script.text != ""
      end
      doc.xpath("id('header')").each(&:remove)
      doc.xpath("//div[contains(@class, 'mega-nav-sandbox')]").each(&:remove)
      doc.xpath("//div[contains(@class, 'docs-sidebar')]").each do |e|
        e.parent.remove
      end
      doc.xpath("id('docs-sidebar')").each(&:remove)
      doc.xpath("id('footer')").each(&:remove)

      doc.xpath('//div[@id="inner"]/h1').each do |e|
        e["style"] = "margin-top: 0px"
      end
      doc.xpath("//div[contains(@role, 'main')]").each do |e|
        e["style"] = "width: 100%"
      end

      File.open(target, "w") { |f| f.write doc }
    else
      cp source, target
    end
  end
end

task :create_index do
  index = Index.new("Nomad.docset/Contents/Resources/docSet.dsidx")
  index.reset

  Dir.chdir("Nomad.docset/Contents/Resources/Documents") do
    # api
    Dir.glob("api/**/*")
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
    # docs/guides
    Dir.glob("guides/**/*")
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

task :import do
  sh "open Nomad.docset"
end

task :package do
  sh "tar --exclude='.DS_Store' -cvzf Nomad.tgz Nomad.docset"
end
