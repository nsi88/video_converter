# encoding: utf-8

module VideoConverter
  class Input
    class << self
      attr_accessor :metadata_command, :show_streams_command, :show_frames_command
    end

    self.metadata_command = "%{ffprobe_bin} %{input} 2>&1"
    self.show_streams_command = "%{ffprobe_bin} -show_streams -select_streams %{stream} %{input} 2>/dev/null"
    self.show_frames_command = "%{ffprobe_bin} -show_frames -select_streams %{stream} %{input} 2>/dev/null | head -n 24"

    attr_accessor :input, :output_groups, :metadata

    def initialize input, outputs = []
      self.input = input or raise ArgumentError.new('Input requred')
      raise ArgumentError.new("#{input} does not exist") unless exists?
    end

    def to_s
      input
    end

    def unescape
      input.gsub(/\\+([^n])/, '\1')
    end

    def metadata
      unless @metadata
        @metadata = {}
        # common metadata
        s = Command.new(self.class.metadata_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :input => input).capture
        if m = s.match(/Stream\s#(\d:\d).*?Audio:\s*(\w+).*?(\d+)\s*Hz.*?(\d+)\s*kb\/s.*?$/)
          @metadata[:audio_stream] = m[1]
          @metadata[:audio_codec] = m[2]
          @metadata[:audio_sample_rate] = m[3].to_i
          @metadata[:audio_bitrate_in_kbps] = m[4].to_i
        end
        @metadata[:channels] = s.scan(/Stream #\d+:\d+/).count
        if m = s.match(/Duration:\s+(\d+):(\d+):([\d.]+).*?bitrate:\s*(\d+)\s*kb\/s/)
          @metadata[:duration_in_ms] = ((m[1].to_i * 3600 + m[2].to_i * 60 + m[3].to_f) * 1000).to_i
          @metadata[:total_bitrate_in_kbps] = m[4].to_i
        end
        if m = s.match(/Stream\s#(\d:\d).*?Video:\s([[:alnum:]]+).*?,\s*((\d+)x(\d+))(?:.*?(\d+)\s*kb\/s.*?([\d.]+)\s*fps)?/)
          @metadata[:video_stream] = m[1]
          @metadata[:video_codec] = m[2]
          @metadata[:width] = m[4].to_i
          @metadata[:height] = m[5].to_i
          @metadata[:video_bitrate_in_kbps] = m[6].to_i
          @metadata[:frame_rate] = m[7].to_f
        end
        if m = s.match(/rotate\s*\:\s*(\d+)/)
          @metadata[:rotate] = m[1].to_i
        end
        if is_http?
          url = URI.parse(input)
          Net::HTTP.start(url.host) do |http|
            response = http.request_head url.path
            @metadata[:file_size_in_bytes] = response['content-length'].to_i
          end
        elsif is_local?
          @metadata[:file_size_in_bytes] = File.size(input.gsub('\\', ''))
        end
        @metadata[:format] = File.extname(input).delete('.')

        # stream metadata
        s = Command.new(self.class.show_streams_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :stream => 'v', :input => input).capture
        @metadata[:video_start_time] = s.match(/start_time=([\d.]+)/).to_a[1].to_f
        @metadata[:video_frame_rate] = s.match(/r_frame_rate=([\d\/]+)/).to_a[1]

        # frame metadata
        s = Command.new(self.class.show_frames_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :stream => 'v', :input => input).capture
        @metadata[:interlaced] = true if s.include?('interlaced_frame=1')
      end
      @metadata
    end

    def select_outputs(outputs)
      outputs.select { |output| !output.path || output.path == input }
    end

    def output_groups(outputs)
      groups = []
      outputs.select { |output| output.type == 'playlist' }.each do |playlist|
        paths = playlist.streams.map { |stream| stream[:path] }
        groups << outputs.select { |output| paths.include?(output.filename) }.unshift(playlist)
      end
      # qualities without playlist are separate groups
      (outputs - groups.flatten).each { |output| groups << [output] }
      groups
    end

    private

    def exists?
      if is_http?
        url = URI.parse(input)
        Net::HTTP.start(url.host) do |http|
          response = http.request_head url.path
          Net::HTTPSuccess === response
        end
      else
        is_local?
      end
    end

    def is_http?
      !!input.match(/^http:\/\//)
    end
    
    def is_local?
      # NOTE method file escapes himself
      File.file?(input.gsub('\\', ''))
    end

  end
end
