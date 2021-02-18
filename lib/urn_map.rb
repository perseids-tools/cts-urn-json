require 'nokogiri'
require 'json'

DEFAULT_CONFIGURATION_FILE = File.expand_path('../config/configuration.json', __dir__)
DEFAULT_TRANSFORMATIONS_FILE = File.expand_path('../config/transformations.json', __dir__)
DEFAULT_TMP_DIRECTORY = File.expand_path('../tmp', __dir__)
DEFAULT_OUTPUT_FILE = File.expand_path('../urn.json', __dir__)

class UrnMap
  def initialize(
    config: DEFAULT_CONFIGURATION_FILE,
    transform: DEFAULT_TRANSFORMATIONS_FILE,
    tmp: DEFAULT_TMP_DIRECTORY,
    out: DEFAULT_OUTPUT_FILE
  )
    @config = config
    @transform = transform
    @tmp = tmp
    @out = out

    @configuration = JSON.parse(File.read(config), symbolize_names: true)
  end

  def init!
    `mkdir -p #{s(tmp)}`

    configuration.each { |group| create_group!(group) }
  end

  def update_configuration!
    configuration.each { |group| update_group!(group) }

    File.open(config, 'w') { |file| file.puts(JSON.pretty_generate(configuration)) }
  end

  def sync_git!
    configuration.each do |group|
      group[:git].each do |repo|
        repo_name = s(File.join(tmp, group[:name], repo[:name]))
        commit = s(repo[:commit])

        `cd #{repo_name} && git fetch && git checkout #{commit}`
      end
    end
  end

  def write_map!
    json = configuration.reduce({}) do |hash, group|
      hash.merge!(parse_files(group))
    end

    File.open(out, 'w') { |file| file.puts(JSON.pretty_generate(json)) }
  end

  private

  attr_accessor :config, :transform, :tmp, :out, :configuration

  def s(string)
    Shellwords.escape(string)
  end

  def create_group!(group)
    name = s(File.join(tmp, group[:name]))
    `mkdir -p #{name}`

    group[:git].each do |repo|
      repo_name = s(File.join(tmp, group[:name], repo[:name]))
      url = s(repo[:url])
      commit = s(repo[:commit])

      `cd #{name} && git clone #{url} #{repo_name}`
      `cd #{repo_name} && git checkout #{commit}`
    end
  end

  def update_group!(group)
    group[:git].each do |repo|
      repo_name = s(File.join(tmp, group[:name], repo[:name]))

      `cd #{repo_name} && git fetch && git reset --hard origin/HEAD`
      sha = `cd #{repo_name} && git rev-parse HEAD`.chomp

      repo[:commit] = sha
    end
  end

  def parse_files(group)
    xml_path = File.join(tmp, group[:name], '**', 'data', '**', '*.xml')
    hash = {}

    Dir[xml_path].each do |file|
      next if /__cts__\.xml/.match?(file)

      urn = file_to_urn(file, group[:prefix])

      xml = Nokogiri::XML(File.read(file))

      add_work_to_hash!(xml, urn, hash)
    end

    hash
  end

  def file_to_urn(file, prefix)
    postfix = File.split(file).last.chomp('.xml')

    "#{prefix}:#{postfix}"
  end

  def clean_string(string)
    string.gsub(/\s/, ' ').squeeze(' ').strip
  end

  def add_work_to_hash!(xml, urn, hash)
    # Several of the XML files aren't correctly namespaced
    xml.remove_namespaces!

    title = xml.xpath('//titleStmt/title').first
    author = xml.xpath('//titleStmt/author').first

    hash[urn] = {
      author: author ? clean_string(author.text) : 'Anonymous',
      title: title ? clean_string(title.text) : 'Unknown',
    }
  end
end
