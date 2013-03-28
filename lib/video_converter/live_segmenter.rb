# encoding: utf-8

module VideoConverter
  class LiveSegmenter
    class << self
      attr_accessor :bin, :command, :segment_length, :filename_prefix, :encoding_profile
    end
    
    self.bin = '/usr/local/bin/live_segmenter'

    self.segment_length = 10

    self.filename_prefix = 's'
    
    self.encoding_profile = 's'

    self.command = '%{ffmpeg_bin} -i %{input} -vcodec libx264 -acodec copy -f mpegts pipe:1 2>>/dev/null | %{live_segmenter_bin} %{segment_length} %{output} %{filename_prefix} %{encoding_profile}'
  end
end
