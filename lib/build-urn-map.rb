#!/usr/bin/env ruby

require 'nokogiri'
require 'json'

def init(configuration)
  `mkdir -p ./tmp`

  configuration.each do |bundle|
    name = bundle['name']
    `mkdir -p "./tmp/#{name}"`

    bundle['git'].each do |repo|
      `cd "./tmp/#{name}" && git clone "#{repo['url']}" "#{repo['name']}"`
      `cd "./tmp/#{name}/#{repo['name']}" && git checkout "#{repo['commit']}"`
    end
  end
end

def update_git!(configuration)
  configuration.each do |bundle|
    bundle['git'].each do |repo|
      `cd "./tmp/#{bundle['name']}/#{repo['name']}" && git fetch && git checkout origin/master`
      sha = `cd "./tmp/#{bundle['name']}/#{repo['name']}" && git rev-parse HEAD`.chomp

      repo['commit'] = sha
    end
  end

  File.open('./urn-map-config.json', 'w') do |file|
    file.puts(JSON.pretty_generate(configuration))
  end
end

def sync_git(configuration)
  configuration.each do |bundle|
    bundle['git'].each do |repo|
      `cd "./tmp/#{bundle['name']}/#{repo['name']}" && git fetch && git checkout "#{repo['commit']}"`
    end
  end
end

def generate_map(configuration)
  json = configuration.reduce({}) do |hash, bundle|
    hash.merge!(parse_files(bundle['name'], bundle['prefix']))
  end

  puts JSON.pretty_generate(json)
end

def file_to_urn(file, prefix)
  postfix = file.split('/').last.chomp('.xml')

  "#{prefix}:#{postfix}"
end

def clean_string(string)
  string.gsub(/\s/, ' ').squeeze(' ').strip
end

def add_work_to_hash!(xml, urn, hash)
  # several of the xml files aren't correctly namespaced
  xml.remove_namespaces!

  title = xml.xpath('//titleStmt/title').first
  author = xml.xpath('//titleStmt/author').first

  hash[urn] = {
    author: author ? clean_string(author.text) : 'Anonymous',
    title: title ? clean_string(title.text) : 'Unknown',
  }
end

def parse_files(name, prefix)
  hash = {}

  Dir["./tmp/#{name}/**/data/**/*.xml"].each do |file|
    next if /__cts__\.xml/.match?(file)

    urn = file_to_urn(file, prefix)

    xml = Nokogiri::XML(File.read(file))

    add_work_to_hash!(xml, urn, hash)
  end

  hash
end

configuration = JSON.parse(File.read('./urn-map-config.json'))

case ARGV[0]
when 'init'
  init(configuration)
when 'update-git'
  update_git!(configuration)
when 'sync-git'
  sync_git(configuration)
when 'map'
  generate_map(configuration)
else
  puts "Usage: #{$PROGRAM_NAME} <init|update-git|sync-git|map>"
end
