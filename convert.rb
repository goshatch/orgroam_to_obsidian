#!/usr/bin/env ruby

require 'sqlite3'
require 'pathname'
require 'pandoc-ruby'
require 'pry'
require 'shellwords'

DB_PATH = './input/org-roam.db'.freeze

class Note
  attr_reader :content

  def initialize(row)
    r = sanitize(row)
    @row = OpenStruct.new(r)
  end

  def id
    @row.id
  end

  def roam_file
    @roam_file ||= "#{@row.file.partition('roam/').last}"
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
  def initialize
    @notes = {}
    db = SQLite3::Database.open(DB_PATH)
    db.results_as_hash = true
    results = db.execute('SELECT * FROM nodes ORDER BY id DESC')
    results.each do |result|
      note = Note.new(result)
      if File.extname(note.input_file) != '.org'
        # Skipping encrypted notes
        puts "Skipping (unsupported file extension): #{note.input_title}"
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
    puts "Converting: #{note.input_title}"
    content = convert_links(note)

    out_path = Pathname("output/#{note.output_file}")
    out_path.dirname.mkpath
    out_path.write(content)
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

Converter.new.convert
