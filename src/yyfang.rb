#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'cgi'
require 'json'
require 'thread'
require 'reline'

# --- 配置参数 ---
BASE_URL = "https://yyfang.top"
SEARCH_URL = "https://yyfang.top/search?page=0&keyword="
NUM_CANDIDATES = 5
MAX_OUTPUT = 2

def get_song(song_name)
  return if song_name.nil? || song_name.empty?

  encoded_kw = CGI.escape(song_name)
  search_uri = URI("#{SEARCH_URL}#{encoded_kw}")

  begin
    search_res = Net::HTTP.get_response(search_uri)
  rescue => e
    return
  end

  unless search_res.is_a?(Net::HTTPSuccess)
    return
  end

  # --- 第一步：从搜索页提取详情页链接 ---
  links = search_res.body.scan(/href="(\/music\/info\.html\?id=[^"]+)"/).flatten.uniq
  candidate_hrefs = links.first(NUM_CANDIDATES)

  if candidate_hrefs.empty?
    return
  end

  # --- 第二步：进入详情页解析网盘链接 ---
  valid_links = []
  mutex = Mutex.new
  threads = []

  candidate_hrefs.each do |href|
    threads << Thread.new do
      detail_uri = URI("#{BASE_URL}#{href}")
      begin
        http = Net::HTTP.new(detail_uri.hostname, detail_uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5
        
        request = Net::HTTP::Get.new(detail_uri)
        request['Referer'] = search_uri.to_s
        request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'

        detail_res = http.request(request)

        if detail_res.is_a?(Net::HTTPSuccess)
          urls = detail_res.body.scan(/data-url="([^"]+)"/).flatten
          urls.each do |quark_url|
            if !quark_url.include?("${")
              mutex.synchronize do
                if valid_links.size < MAX_OUTPUT
                  valid_links << quark_url
                end
              end
            end
          end
        end
      rescue
      end
    end
  end

  # 等待该歌曲的所有详情页线程执行完毕
  threads.each(&:join)

  # --- 格式输出 ---
  if valid_links.any?
    puts "```#{song_name}"
    valid_links.each { |link| puts link }
    puts "```"
    puts "" # 歌曲间空行
  end
end

# --- 主逻辑---
if ARGV.empty? then
  song = Reline.readline("> 歌名：")
  abort "[yyfang]: input is empty" if song.strip.empty?
  get_song(song)
else
  ARGV.each do |path|
    abort "[yyfang]: No Such File `#{path}`" unless File.file?(path)
    File.readlines(path).each do |song|
      get_song(song)
    end
  end
end

