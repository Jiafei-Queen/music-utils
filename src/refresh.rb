#!/usr/bin/env ruby

require 'zlib'
require 'fileutils'
require 'json'

LEN = 40
SAMPLE_SIZE = 512 * 1024
FILENAME = ".sync_hash.json"

# 进度条
def progress(total, current, path, act)
  counter = "(#{current.to_s.rjust(total.to_s.length)}/#{total})"
  
  # 目标显示总宽度 (减去 counter 和 act 占用的宽度)
  max_path_width = LEN 
  
  # 如果当前路径太长，进行截断
  # 这里为了保险，直接用最简单粗暴的截断，或者保留原样但确保 \r 正常
  display_path = path

  # 计算全角字符的数量，每个全角字符额外增加 1 个单位宽度
  # 这是一个近似算法，涵盖了绝大多数中日韩文字
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

# 哈希计算（adler32 对文件大小，文件头尾各 2MB 计算）
def hash(path)
  return nil unless File.file?(path)
  size = File.size(path)
  
  File.open(path, 'rb') do |handle|
    if size <= SAMPLE_SIZE
      data = handle.read
    else
      # 读取头部 2MB
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

def usage()
  puts "Usage: ./refresh.rb [path]"
end
 
# ----- [ 逻辑开始 ] -----

(usage(); exit) unless ARGV.size == 1
target = ARGV[0]
abort "[Sync]: ERROR: No Such Dir `#{target}`" unless File.directory?(target)

refresh(target)
