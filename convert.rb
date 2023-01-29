#!/usr/bin/env ruby

require 'sqlite3'
require 'pathname'
require 'pandoc-ruby'
require 'pry'

DB_PATH = './input/org-roam.db'.freeze

class Note
  attr_reader :content

  def initialize(row)
    r = sanitize(row)
    @row = OpenStruct.new(r)
    @content = input_file_to_md
  end

  def id
    @row.id
  end

  def input_file
    @input_file ||= "input/roam/#{@row.file.partition('roam/').last}"
  end

  def title
    @row.title
  end

  def filename
    "#{title}.md".gsub(%r{[\x00\/\\:\*\?\"<>\|]}, '-')
  end

  private

  def input_file_to_md
    PandocRuby.new([input_file], from: 'org', wrap: 'none').to_gfm
  end

  def sanitize(row)
    r = row.map do |k, v|
      if v.is_a? String
        [k, v.gsub("\"", '')]
      else
        [k, v]
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
      puts "Loading: #{note.title}"
      @notes[note.id] = note
    end
    puts '✅ Done loading.'
  end

  def convert
    @notes.each_key { |key| convert_and_write_note(@notes[key]) }
    puts '✅ Done converting.'
  end

  def convert_and_write_note(note)
    puts "Converting: #{note.title}"
    content = convert_links(note)
    File.write("output/#{note.filename}", content)
  end

  def convert_links(note)
    note.content.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |_match|
      link_text = ::Regexp.last_match(1)
      link_target = ::Regexp.last_match(2)

      if link_target.start_with?('id:')
        target_note_id = link_target.sub('id:', '')
        target_note = @notes[target_note_id]

        "[[#{target_note.title}]]"
      else
        "[#{link_text}](#{link_target})"
      end
    end
  end
end

Converter.new.convert
