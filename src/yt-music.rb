#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'colorize'
require 'reline'
require 'optparse'

FORMAT = "m4a"
songs = []
options = {}

# 解析参数
OptionParser.new do |opts|
  opts.banner = "Usage: yt-music.rb"

  opts.on("-u", "--url URL") do |u|
    options[:url] = u
  end

  opts.on("-a", "--artist artist") do |a|
    options[:artist] = a
  end

  opts.on("-n", "--name song_name") do |n|
    options[:name] = n
  end
end.parse!

# 手动补全信息
if !options[:artist] then
  options[:artist] = Reline.readline("> 歌手：")
end

if !options[:name] then
  options[:name] = Reline.readline("> 歌名：")
end

# 获取 JSON 路径
json_path = ARGV[0]

if json_path && File.file?(json_path)
  # 原有的 JSON 解析逻辑
  content = File.read(json_path)
  data = JSON.parse(content)
  data['albums'].each do |album|
    album_name = (album['name']&.strip&.empty? ? nil : album['name'])
    album['songs'].each do |song_name|
      songs << { album: album_name, author: album['author'], song: song_name }
    end
  end
else
  songs << {
    author: options[:artist],
    song: options[:name],
    url: options[:url] ? options[:url] : nil
  }
end
  

# 3. 执行下载逻辑
songs.each do |item|
  author = item[:author]
  output_author = author.gsub("/", "_")
  name = item[:song].gsub("'", "").gsub('"', '')
  output_name = item[:song].gsub("/", "_")
  album = item[:album]
  output_album = album.gsub("/", "_") if album

  dir_path = album ? File.join(output_author, output_album) : "."
  FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)

  output_base = album ? File.join(dir_path, output_name) : "#{output_name} - #{author}"
  output_file = "#{output_base}.#{FORMAT}"

  if File.file?(output_file)
    puts "\n#{"--- [ 已存在 #{output_file}，跳过 >> ] ---".red}\n"
    next
  end

  puts "\n#{"--- [ 正在下载: #{name} - #{author} ] ---".green}\n"

  # 4. 动态确定搜索词或 URL
  # 如果 item 中有 :url，则直接使用；否则使用 ytsearch1 搜索
  target = item[:url] ? item[:url] : "ytsearch1:##{author} #{name}"

  args = [
    "yt-dlp",
    "--cookies-from-browser", "firefox",
    "-x",
    "--audio-format", FORMAT,
    "--audio-quality", "0",
    "--embed-thumbnail",
    "--add-metadata",
    "--output", output_base,
    "--postprocessor-args", "ffmpeg:-metadata title='#{item[:song]}' -metadata artist='#{author}'",
    "--sleep-interval", "5",
    "--max-sleep-interval", "10",
    target
  ]

  system(*args)
end
