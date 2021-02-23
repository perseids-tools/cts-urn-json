require 'nokogiri'
require 'json'

require_relative './shell'
require_relative './group'

DEFAULT_CONFIGURATION_FILE = File.expand_path('../config/configuration.json', __dir__)
DEFAULT_TRANSFORMATIONS_FILE = File.expand_path('../config/transformations.json', __dir__)
DEFAULT_TMP_DIRECTORY = File.expand_path('../tmp', __dir__)
DEFAULT_OUTPUT_FILE = File.expand_path('../urn.json', __dir__)

class UrnMap
  include Shell

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
    @transformations = JSON.parse(File.read(transform), symbolize_names: true)
  end

  def init!
    `mkdir -p #{s(tmp)}`

    configuration.each { |group| Group.new(group, tmp).init! }
  end

  def update_configuration!
    configuration.each { |group| Group.new(group, tmp).update! }
    json = JSON.pretty_generate(configuration)

    if config == '-'
      puts(json)
    else
      File.open(config, 'w') { |file| file.puts(json) }
    end
  end

  def sync_git!
    configuration.each { |group| Group.new(group, tmp).sync! }
  end

  def write_map!
    map = configuration.reduce({}) do |hash, group|
      hash.merge!(parse_files(group))
    end
    json = JSON.pretty_generate(map)

    if out == '-'
      puts(json)
    else
      File.open(out, 'w') { |file| file.puts(json) }
    end
  end

  private

  attr_reader :config, :transform, :tmp, :out, :configuration, :transformations

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

  def text_from_node(node)
    return '' unless node

    node.text.gsub(/\s/, ' ').squeeze(' ').strip
  end

  def add_work_to_hash!(xml, urn, hash)
    # Several of the XML files aren't correctly namespaced
    xml.remove_namespaces!

    title = text_from_node(xml.xpath('//titleStmt/title').first)
    author = text_from_node(xml.xpath('//titleStmt/author').first)

    transform_and_add_to_hash!(urn, author, title, hash)
  end

  def run_transform(match, transform, key, var)
    if (!match || (match[key] && Regexp.new(match[key]) =~ var)) && transform[key]
      return var.gsub(Regexp.new(transform[key][0]), transform[key][1])
    end

    var
  end

  def transform_and_add_to_hash!(urn, author, title, hash)
    transformations.each do |group|
      match = group[:match]
      transform = group[:transform]

      urn = run_transform(match, transform, :urn, urn)
      title = run_transform(match, transform, :title, title)
      author = run_transform(match, transform, :author, author)
    end

    hash[urn] = { author: author, title: title }
  end
end
