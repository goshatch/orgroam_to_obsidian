#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'sqlite3'
require 'pathname'
require 'pandoc-ruby'
require 'pry'
require 'shellwords'

DB_PATH = './input/org-roam.db'.freeze

class Note
  def initialize(row, debug: false, roam_root: nil)
    r = sanitize(row)
    @row = OpenStruct.new(r)
    @debug = debug
    @roam_root = roam_root || File.expand_path("~/org-roam")
  end

  def id
    @row.id
  end

  def roam_file
    @roam_file ||= "#{@row.file.partition(@roam_root).last}"
  end

  def input_file
    @input_file ||= "input/roam/#{roam_file}"
  end

  def title
    @row.title.gsub(%r{[\x00\/\\:\*\?\"<>\|]}, '-')
  end

  def input_title
    @row.title
  end

  def output_file
    Pathname(@roam_file).dirname + "#{title}.md"
  end

  def content
    input_file_to_md
  end

  private

  def input_file_to_md
    PandocRuby.new([(Shellwords.escape input_file)], :standalone, from: 'org', wrap: 'none').to_gfm
  end

  def sanitize(row)
    r = row.map do |k, v|
      key = k.to_s.to_sym
      if v.is_a? String
        [key, v.gsub('"', '')]
      else
        [key, v]
      end
    end
    r.to_h
  end
end

class Converter
  def initialize(debug: false, roam_root: nil)
    @debug = debug
    @notes = {}
    db = SQLite3::Database.open(DB_PATH)
    db.results_as_hash = true
    results = db.execute('SELECT * FROM nodes ORDER BY id DESC')
    if @debug
      puts "Warn: no nodes found in database" if results.length == 0
    end
    results.each do |result|
      note = Note.new(result, debug: debug, roam_root: roam_root)
      if File.extname(note.input_file) != '.org'
        # Skipping encrypted notes
        puts "Skipping (unsupported file extension): #{note.input_title}"
        if @debug
          puts "\tinput file: #{note.input_file}"
          puts "\tfile relative to roam dir: #{note.roam_file}"
          puts "\textension: #{File.extname(note.input_file)}"
        end

        next
      end

      puts "Loading: #{note.input_title}"
      @notes[note.id] = note
    end
    puts '✅ Done loading.'
  end

  def convert
    @notes.each_key { |key| convert_and_write_note(@notes[key]) }
    puts '✅ Done converting.'
  end

  def convert_and_write_note(note)
    begin
      puts "Converting: #{note.input_title}"
      content = convert_links(note)

      out_path = Pathname("output/#{note.output_file}")
      out_path.dirname.mkpath
      out_path.write(content)
    rescue StandardError => e
      puts "Failed to convert and write note: #{note.input_title}"
      puts "\tError: #{e.message}"
      puts e.backtrace if @debug
    end
  end

  def convert_links(note)
    note.content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |_match|
      link_text = ::Regexp.last_match(1)
      link_target = ::Regexp.last_match(2)

      if link_target.start_with?('id:')
        target_note_id = link_target.sub('id:', '')
        target_note = @notes[target_note_id]

        if target_note.nil?
          "[Note not found: #{link_text}](#{link_target})"
        else
          "[[#{target_note.title}]]"
        end
      else
        "[#{link_text}](#{link_target})"
      end
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: convert.rb [options]"

  opts.on('--debug', 'Run with debug output') do
    options[:debug] = true
    puts "Running with DEBUG output"
  end
  
  opts.on('--roam-root PATH', 'Path to actual org-roam directory') do |path|
    unless Dir.exist?(path)
      puts "Error: The specified org-root path '#{path}' does not exist or is not a directory"
      exit 1
    end
    options[:roam_root] = path
  end
end.parse!

Converter.new(debug: options[:debug], roam_root: options[:roam_root]).convert
