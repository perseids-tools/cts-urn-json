#!/usr/bin/env ruby

require 'optparse'
require_relative '../lib/urn_map'

options = {}
commands = <<~COMMANDS
  init      Initialize repositories in the temporary directory
  update    Pull the latest version of the repos and update the configuration
  sync      Check out the version of the repos specified in the configuration
  generate  Generate the urn.json file
COMMANDS

show_help = false

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: urn.rb <init|update|sync|generate> [options]'

  opts.on('-r', '--repos REPOS', 'Repository configuration file location', 'Default: ./config/repositories.json') do |r|
    options[:repos] = r
  end

  opts.on('-t', '--transform TRANSFORM', 'Transformations file location',
    'Default: ./config/transformations.json') do |t|
    options[:transform] = t
  end

  opts.on('-m', '--tmp TMP', 'teMporary directory location', 'Default: ./tmp/') do |m|
    options[:tmp] = m
  end

  opts.on('-o', '--out OUT', 'Output file location', 'Default: ./urn.json') do |o|
    options[:out] = o
  end

  opts.on('-h', '--help', 'Help message display') do
    show_help = true
  end
end

parser.parse!

if ARGV.size != 1
  show_help = true
end

command = ARGV.shift

unless %w[init update sync generate].member?(command)
  show_help = true
end

if show_help
  puts(parser)
  puts(commands)

  exit
end

urn_map = UrnMap.new(**options)

case command
when 'init' then urn_map.init!
when 'update' then urn_map.update_repositories!
when 'sync' then urn_map.sync_git!
when 'generate' then urn_map.write_map!
end
