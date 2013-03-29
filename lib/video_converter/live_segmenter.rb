# encoding: utf-8

module VideoConverter
  class LiveSegmenter
    class << self
      attr_accessor :bin, :ffprobe_bin, :chunks_command, :segment_length, :filename_prefix, :encoding_profile, :delete_input
    end
    
    self.bin = '/usr/local/bin/live_segmenter'

    self.ffprobe_bin = '/usr/local/bin/ffprobe'

    self.segment_length = 10

    self.filename_prefix = 's'
    
    self.encoding_profile = 's'

    self.delete_input = true

    self.chunks_command = '%{ffmpeg_bin} -i %{input} -vcodec libx264 -acodec copy -f mpegts pipe:1 2>>/dev/null | %{bin} %{segment_length} %{output_dir} %{filename_prefix} %{encoding_profile}'

    attr_accessor :profile, :playlist_dir, :paral, :segment_length, :filename_prefix, :encoding_profile, :delete_input, :chunk_base

    def initialize params
      [:profile, :playlist_dir].each do |param|
        self.send("#{param}=", params[param])
      end
      [:segment_length, :filename_prefix, :encoding_profile, :delete_input].each do |param|
        self.send("#{param}=", params[param].nil? ? self.class.send(param) : params[param])
      end
      self.chunk_base = params[:chunk_base] ? params[:chunk_base] : '.'
      self.chunk_base += '/' unless chunk_base.end_with?('/')
    end

    def run
      res = true
      threads = []
      p = Proc.new do |profile|
        input = profile.to_hash[:output_file]
        output = profile.to_hash[:output_dir]
        make_chunks(input, output) && gen_quality_playlist(output, "#{File.basename(output)}.m3u8")
      end
      [profile].flatten.each do |profile|
        if paral
          threads << Thread.new { res &&= p.call(profile) }
        else
          res &&= p.call(profile)
        end
      end
      gen_group_playlists
    end

    private

    def make_chunks input, output
      params = {}
      [:segment_length, :filename_prefix, :encoding_profile].each { |param| params[param] = self.send(param) }
      command = Command.new self.class.chunks_command, params.merge(:input => input, :output_dir => output).merge(common_params)
      res = command.execute
      FileUtils.rm input if delete_input
      res
    end

    def gen_quality_playlist chunks_dir, playlist_name
      res = ''
      durations = []
      Dir::glob(File.join(chunks_dir, 's-*[0-9].ts')).each do |chunk|
        durations << (duration = chunk_duration chunk)
        res += "#EXTINF:#%0.2f\n" % duration
        res += "#{chunk_base}#{File.basename(chunks_dir)}/#{File.basename(chunk)}\n"
      end
      res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:#{durations.max}\n#EXT-X-MEDIA-SEQUENCE:0\n" + res + "#EXT-X-ENDLIST"
      File.open(File.join(playlist_dir, playlist_name), 'w') { |f| f.write res }
    end

    def gen_group_playlists
      Profile.groups(profile).each_with_index do |group, index|
        res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD"
        group.sort { |g1, g2| g1.to_hash[:bandwidth] <=> g2.to_hash[:bandwidth] }.each do |quality|
          res += "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=#{quality.to_hash[:bandwidth] * 1000}\n"
          res += File.join(chunk_base, playlist_dir, File.basename(quality.to_hash[:output_dir]) + '.m3u8')
        end
        res += "#EXT-X-ENDLIST"
        File.open(File.join(playlist_dir, "playlist#{index + 1}.m3u8"), 'w') { |f| f.write res }
      end
    end

    def common_params
      { :ffmpeg_bin => Ffmpeg.bin, :bin => self.class.bin }
    end

    def chunk_duration chunk
      s = `#{self.class.ffprobe_bin} #{chunk} 2>&1`.match(/Duration:.*(?:[0-9]{2}):(?:[0-9]{2}):([0-9]{2}(?:\.[0-9]{2})?)/).to_a[1].to_f
    end
  end
end
