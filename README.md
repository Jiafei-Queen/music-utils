# Music Utils

一些我自己会用到的与 **下载音乐** 有关的脚本

- `sync.rb` & `refresh.rb`
    - 对音乐库中每首歌前 512KB 做 Albert32 哈希计算
    - 对比本地和目标目录下的哈希文件
    - 同步歌曲...

- `yt-music.rb` & `yt-video.rb`
    - 对于 `yt-dlp` 的封装，用于从 Youtube 下载音频和视频

- `yyfang.rb`
    - 爬取 `yyfang.top` 网站的夸克网盘链接

- `foa`
    - 封装 `ffmpeg` 的 FLAC -> ALAC 脚本

- `mbr`
    - 封装 `ffprobe` 的 **检测音频文件码率** 的脚本（是文件码率非音频码率）

- `square`
    - 使用 `ffmpeg` 将图片裁剪成正方形，方便将不同的图片变成专辑封面
