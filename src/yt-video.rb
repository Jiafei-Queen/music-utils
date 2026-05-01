#!/usr/bin/env ruby
require 'optparse'
require 'reline'

def print_usage()
  puts "Usage: ~ [-k|--keyword keyword] [-u|--url url]"
end

if ARGV.size < 2 || ARGV.size % 2 != 0 then
  print_usage()
  return
end

keyword = nil
url = nil
output = nil
ARGV.each_slice(2) do |flag, option|
  case flag
  when "-k", "--key-word"
    if !url && !keyword then
      keyword = option
    else
      print_usage()
      return
    end
  when "-u", "--url"
    if !keyword && !url then
      url = option
    else
      print_usage()
      return
    end
end

target = url ? url : "ytsearch1:#{keyword}"

args = [
  "yt-dlp",
  "--cookies-from-browser", "firefox",
  "-f", "bestvideo+bestaudio/best",
  "--merge-output-format", "mp4",
  "--embed-thumbnail",
  "--add-metadata",
  "--output", "%(title)s.%(ext)s",
  "--sleep-interval", "5",
  "--max-sleep-interval", "10",
  target
]

system(*args)
