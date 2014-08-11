# encoding: utf-8

module VideoConverter
  class LiveSegmenter
    class << self
      attr_accessor :bin, :chunk_prefix, :encoding_profile, :select_streams, :command
    end
    
    self.bin = '/usr/local/bin/live_segmenter'
    self.chunk_prefix = 's'
    self.encoding_profile = 's'
    self.select_streams = 'v'

    self.command = '%{ffmpeg_bin} -i %{ffmpeg_output} -c:v copy -c:a copy -f mpegts pipe:1 2>>/dev/null | %{bin} %{keyframe_interval_in_seconds} %{chunks_dir} %{chunk_prefix} %{encoding_profile} 1>>%{log} 2>&1'

    def self.run(outputs)
      success = true
      threads = []
      p = Proc.new do |output|
        make_chunks(output) && gen_quality_playlist(output)
      end
      outputs.select { |output| output.type != 'playlist' }.each do |output|
        if VideoConverter.paral
          threads << Thread.new { success &&= p.call(output) }
        else
          success &&= p.call(output)
        end
      end
      success &&= gen_group_playlist(outputs.detect { |output| output.type == 'playlist' })
      threads.each { |t| t.join } if VideoConverter.paral
      success
    end

    private

    def self.make_chunks output
      Command.new(command, prepare_params(output)).execute
    end

    def self.gen_quality_playlist output
      res = ''
      durations = []
      # order desc
      chunks = Dir::glob(File.join(output.chunks_dir, "#{chunk_prefix}-*[0-9].ts")).sort do |c1, c2| 
        File.basename(c2).match(/\d+/).to_s.to_i <=> File.basename(c1).match(/\d+/).to_s.to_i
      end
      # chunk duration = (pts of first frame of the next chunk - pts of first frame of current chunk) / time_base
      # for the last chunks the last two pts are used
      prl_pts, l_pts = `#{Ffmpeg.ffprobe_bin} -show_frames -select_streams #{select_streams} -print_format csv -loglevel fatal #{chunks.first} | tail -n2 2>&1`.split("\n").map { |l| l.split(',')[3].to_i }
      # NOTE for case when chunk has one frame
      l_pts ||= prl_pts
      next_chunk_pts = 2 * l_pts - prl_pts
      time_base = `#{Ffmpeg.ffprobe_bin} -show_streams -select_streams #{select_streams} -loglevel fatal #{chunks.first} 2>&1`.match(/\ntime_base=1\/(\d+)/)[1].to_f
      chunks.each do |chunk|
        pts = `#{Ffmpeg.ffprobe_bin} -show_frames -select_streams #{select_streams} -print_format csv -loglevel fatal #{chunk} | head -n1 2>&1`.split(',')[3].to_i
        durations << (duration = (next_chunk_pts - pts) / time_base)
        next_chunk_pts = pts
        res = File.join(File.basename(output.chunks_dir), File.basename(chunk)) + "\n" + res
        res = "#EXTINF:%0.2f,\n" % duration + res
      end
      res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:#{durations.max.to_f.ceil}\n#EXT-X-MEDIA-SEQUENCE:0\n" + res + "#EXT-X-ENDLIST"
      !!File.open(File.join(output.work_dir, output.filename), 'w') { |f| f.write res }
    end

    def self.gen_group_playlist playlist
      res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD\n"
      playlist.streams.sort { |s1, s2| s1[:bandwidth].to_i <=> s2[:bandwidth].to_i }.each do |stream|
        res += "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=#{stream[:bandwidth].to_i * 1000}\n"
        res += stream[:path] + "\n"
      end
      res += "#EXT-X-ENDLIST"
      File.open(File.join(playlist.work_dir, playlist.filename), 'w') { |f| f.write res }
      true
    end

    def self.prepare_params output
      {
        :ffmpeg_bin => Ffmpeg.bin,
        :ffmpeg_output => output.ffmpeg_output,
        :bin => bin,
        :keyframe_interval_in_seconds => Output.keyframe_interval_in_seconds,
        :chunks_dir => output.chunks_dir,
        :chunk_prefix => chunk_prefix,
        :encoding_profile => encoding_profile,
        :log => output.log
      }
    end
  end
end
