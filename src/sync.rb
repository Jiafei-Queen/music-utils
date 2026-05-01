#!/usr/bin/env ruby

require 'zlib'
require 'fileutils'
require 'json'

LEN = 40
SAMPLE_SIZE = 512 * 1024
FILENAME = ".sync_hash.json"
LOCAL = "/Users/jiafei/Music/Music/Media.localized/Music"
TARGETS = {
  "walkman" => "/Volumes/WALKMAN/MUSIC",
  "sd" => "/Volumes/SD_CARD/MUSIC",
  "pi" => "/Volumes/Music"
}

# 进度条
def progress(total, current, path, act)
  counter = "(#{current.to_s.rjust(total.to_s.length)}/#{total})"

  max_path_width = LEN 
  display_path = path

  # 每个全角字符额外增加 1 个单位宽度
  display_width = path.chars.sum { |c| c.bytesize > 1 ? 2 : 1 }
  if display_width > max_path_width
    # 简单的后截断：从后面截取，直到宽度合适
    display_path = "..."
    current_w = 3
    path.chars.reverse_each do |c|
      w = c.bytesize > 1 ? 2 : 1
      break if current_w + w > max_path_width
      display_path.insert(3, c)
      current_w += w
    end
  else
    # 补全空格
    padding = max_path_width - display_width
    display_path = path + (" " * [padding, 0].max)
  end

  print "\r#{counter} #{act}: #{display_path}\e[K"
  $stdout.flush
end

# 哈希计算（adler32 对文件大小，文件头 512KB 计算）
def hash(path)
  return nil unless File.file?(path)
  size = File.size(path)
  
  File.open(path, 'rb') do |handle|
    if size <= SAMPLE_SIZE
      data = handle.read
    else
      head = handle.read(SAMPLE_SIZE)
      data = "#{size}#{head}"
    end
    Zlib.adler32(data).to_s(16)
  end
rescue => e
  puts "[Hash]: ERROR: at `#{path}`: #{e.message}"
  nil
end

# 计算 path 下音频文件的哈希并返回 path - hash 哈希表
def glob_hash(path)
  base_path = Pathname.new(path).cleanpath.to_s + "/"
  results = {}
  
  files = Dir.glob("#{base_path}**/*.{m4a,mp3}")
             .reject { |f| File.basename(f).start_with?('._') }
  
  total = files.size
  files.each_with_index do |file, index|
    relative_path = file.gsub(base_path, '').unicode_normalize(:nfc)
    progress(total, index + 1, relative_path, "Hashing")
    results[relative_path] = hash(file)
  end
  
  puts ""
  results
end

# 更新索引
def refresh(path)
  puts "--- [ Hashing... ] ---\n"
  hash_data = glob_hash(path)
  File.write(File.join(path, FILENAME), JSON.pretty_generate(hash_data))
end

# 比较索引，返回有 rm 和 cp 数组的表
def diff(target)
  local_hash_file = File.join(LOCAL, FILENAME)
  target_hash_file = File.join(target, FILENAME)

  refresh(LOCAL) unless $skip_hash

  [local_hash_file, target_hash_file].each_with_index do |path, i|
    unless File.file?(path)
      puts "[Diff]: Hash File Not Found at `#{path}`"
      puts "Please Copy Your Whole Music Lib to Target for INIT" if i == 1
      exit
    end
  end

  local_status = JSON.parse(File.read(local_hash_file))
  target_status = JSON.parse(File.read(target_hash_file))

  cp = []; rm = []
  rm = target_status.keys - local_status.keys

  # 找出需要更新或新增的文件
  local_status.each do |file, h|
    if !target_status.has_key?(file)
      cp << file
    elsif target_status[file] != h
      rm << file
      cp << file
    end
  end

  { cp: cp, rm: rm }
end

# --- [ 同步 ] ---
def sync(diff, target)
  puts "--- [ Syncing to #{target}... ] ---\n"

  total = diff[:rm].size + diff[:cp].size
  current = 0

  # 1. 删除文件
  diff[:rm].each do |relative_path|
    target_path = File.join(target, relative_path)
    if File.exist?(target_path)
      FileUtils.rm(target_path)
    end
    current += 1
    progress(total, current, relative_path, "Remove")
  rescue => e; warn "[Remove]: ERROR: #{e.message}"; end

  # 2. 复制文件
  diff[:cp].each do |relative_path|
    source_path = File.join(LOCAL, relative_path)
    target_path = File.join(target, relative_path)
    FileUtils.mkdir_p(File.dirname(target_path))
    FileUtils.cp(source_path, target_path)

    current += 1
    progress(total, current, relative_path, "Copying")
  rescue => e; warn "[Copy]: ERROR: #{e.message}"; end

  # 3. 清理残留的空目录
  # 从最深层级开始向上传递式删除
  puts "\n\n--- [ Cleaning empty directories... ] ---\n"
  Dir.glob(File.join(target, "**", "*/")).sort_by { |d| -d.length }.each do |dir|
    if (Dir.entries(dir) - %w[. .. .DS_Store ._]).empty?
      Dir.rmdir(dir)
      puts "[Clean]: #{dir.gsub(target, '')}"
    end
  rescue => e; next; end

  # 4. 更新索引
  FileUtils.cp(File.join(LOCAL, FILENAME), File.join(target, FILENAME))
  puts "--- [ Done!! ] ---"
end

def usage()
  puts "Usage: ./sync.rb [sync|test|refresh] [walkman|sd|pi] [--skip-hash]"
end
 
# ----- [ 逻辑开始 ] -----

$skip_hash = ARGV.delete("--skip-hash")
action = ARGV.find { |arg| %w[sync test refresh].include?(arg) }
target_key = ARGV.find { |arg| TARGETS.keys.include?(arg) }

if action.nil? || (action != "refresh" && target_key.nil?)
  usage()
  exit
end

target = TARGETS[target_key]
target = LOCAL if target.nil? && action == "refresh"
abort "[Sync]: ERROR: No Such Dir `#{target}`" unless File.directory?(target)

case action
when "sync"
  sync(diff(target), target)
when "refresh"
  refresh(target)
when "test"
  res = diff(target)
  puts "--- [ Testing for #{target_key.upcase} ] ---"
  puts "Remove:"; pp res[:rm]
  puts "Copy:";   pp res[:cp]
end
