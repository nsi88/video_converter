# encoding: utf-8

module VideoConverter
  class LiveSegmenter
    class << self
      attr_accessor :chunks_pattern, :command
    end
    
    self.chunks_pattern = 's-%05d.ts'
    self.command = '%{ffmpeg_bin} -i %{ffmpeg_output} -c copy -map 0 -f ssegment -segment_time %{segment_time} -segment_list %{segment_list} -segment_list_entry_prefix %{segment_list_entry_prefix} %{chunks} 1>>%{log} 2>&1'

    def self.run(outputs)
      success = true
      threads = []
      p = Proc.new do |output|
        Command.new(command, prepare_params(output)).execute
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

    def self.gen_group_playlist playlist
      res = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-PLAYLIST-TYPE:VOD\n"
      playlist.streams.sort { |s1, s2| s1[:bandwidth].to_i <=> s2[:bandwidth].to_i }.each do |stream|
        res += "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=#{stream[:bandwidth].to_i * 1000}\n"
        res += stream[:path] + "\n"
      end
      res += "#EXT-X-ENDLIST\n"
      File.open(File.join(playlist.work_dir, playlist.filename), 'w') { |f| f.write res }
      true
    end

    def self.prepare_params output
      {
        :ffmpeg_bin => Ffmpeg.bin,
        :ffmpeg_output => output.ffmpeg_output,
        :segment_time => Output.keyframe_interval_in_seconds,
        :segment_list => File.join(output.work_dir, output.filename),
        :segment_list_entry_prefix => File.basename(output.chunks_dir) + '/',
        :chunks => File.join(output.chunks_dir, chunks_pattern),
        :log => output.log
      }
    end
  end
end
