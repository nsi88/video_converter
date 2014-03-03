# encoding: utf-8

module VideoConverter
  class LiveSegmenter
    class << self
      attr_accessor :bin, :ffprobe_bin, :chunks_command, :chunk_prefix, :encoding_profile, :log, :paral, :select_streams
    end
    
    self.bin = '/usr/local/bin/live_segmenter'
    self.ffprobe_bin = '/usr/local/bin/ffprobe'
    self.chunk_prefix = 's'
    self.encoding_profile = 's'
    self.log = '/dev/null'
    self.paral = true
    self.select_streams = 'v'

    self.chunks_command = '%{ffmpeg_bin} -f mp4 -i %{local_path} -vcodec copy -acodec copy -f mpegts -bsf h264_mp4toannexb pipe:1 2>>/dev/null | %{bin} %{segment_seconds} %{chunks_dir} %{chunk_prefix} %{encoding_profile} 1>>%{log} 2>&1'

    attr_accessor :paral, :chunk_prefix, :encoding_profile, :log, :output_array

    def initialize params
      self.output_array = params[:output_array] or raise ArgumentError.new("output_array is needed")
      [:chunk_prefix, :encoding_profile, :log, :paral].each do |param|
        self.send("#{param}=", params[param].nil? ? self.class.send(param) : params[param])
      end
    end

    def run
      res = true
      threads = []
      p = Proc.new do |output|
        make_chunks(output) && gen_quality_playlist(output)
      end
      output_array.playlists.each do |playlist|
        playlist.items.each do |item|
          if paral
            threads << Thread.new { res &&= p.call(item) }
          else
            res &&= p.call(item)
          end
        end
        res &&= gen_group_playlist playlist
      end
      threads.each { |t| t.join } if paral
      res
    end

    private

    def make_chunks output
      Command.new(self.class.chunks_command, common_params.merge(output.to_hash)).execute
    end

    def gen_quality_playlist output
      res = ''
      durations = []
      # order desc
      chunks = Dir::glob(File.join(output.chunks_dir, "#{chunk_prefix}-*[0-9].ts")).sort do |c1, c2| 
        File.basename(c2).match(/\d+/).to_s.to_i <=> File.basename(c1).match(/\d+/).to_s.to_i
      end
      # chunk duration = (pts of first frame of the next chunk - pts of first frame of current chunk) / time_base
      # for the last chunks the last two pts are used
      prl_pts, l_pts = `#{self.class.ffprobe_bin} -show_frames -select_streams #{self.class.select_streams} -print_format csv -loglevel fatal #{chunks.first} | tail -n2 2>&1`.split("\n").map { |l| l.split(',')[3].to_i }
      next_chunk_pts = 2 * l_pts - prl_pts
      chunks.each do |chunk|
        durations << (duration = (next_chunk_pts - (next_chunk_pts = 
          `#{self.class.ffprobe_bin} -show_frames -select_streams #{self.class.select_streams} -print_format csv -loglevel fatal #{chunk} | head -n1 2>&1`.split(',')[3].to_i
        )) / `#{self.class.ffprobe_bin} -show_streams -select_streams #{self.class.select_streams} -loglevel fatal #{chunk} 2>&1`.match(/\ntime_base=1\/(\d+)/)[1].to_f)
        res = File.join(File.basename(output.chunks_dir), File.basename(chunk)) + "\n" + res
        res = "#EXTINF:%0.2f,\n" % duration + res
      end
      res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:#{durations.max}\n#EXT-X-MEDIA-SEQUENCE:0\n" + res + "#EXT-X-ENDLIST"
      File.open(File.join(output.work_dir, output.filename), 'w') { |f| f.write res }
    end

    def gen_group_playlist playlist
      res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD\n"
      playlist.streams.sort { |s1, s2| s1[:bandwidth].to_i <=> s2[:bandwidth].to_i }.each do |stream|
        res += "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=#{stream[:bandwidth].to_i * 1000}\n"
        res += stream[:path] + "\n"
      end
      res += "#EXT-X-ENDLIST"
      File.open(File.join(playlist.work_dir, playlist.filename), 'w') { |f| f.write res }
      true
    end

    def common_params
      { :ffmpeg_bin => Ffmpeg.bin, :bin => self.class.bin, :log => log, :chunk_prefix => chunk_prefix, :encoding_profile => encoding_profile }
    end
  end
end
