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

    def metadata
      unless @metadata
        @metadata = {}
        # common metadata
        s = Command.new(self.class.metadata_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :input => input).capture
        @metadata[:channels] = s.scan(/Stream #\d+:\d+/).count
        if m = s.match(/Duration:\s+(\d+):(\d+):([\d.]+).*?bitrate:\s*(\d+)\s*kb\/s/)
          @metadata[:duration_in_ms] = ((m[1].to_i * 3600 + m[2].to_i * 60 + m[3].to_f) * 1000).to_i
          @metadata[:total_bitrate_in_kbps] = m[4].to_i
        end
        @metadata[:audio_streams] = s.scan(/Stream\s#(\d:\d).*?Audio:\s*(\w+).*?(\d+)\s*Hz.*?(\d+)\s*kb\/s.*?$/).map do |stream|
          Hash[[:map, :audio_codec, :audio_sample_rate, :audio_bitrate_in_kbps].zip(stream)]
        end
        @metadata[:video_streams] = s.scan(/Stream\s#(\d:\d).*?Video:\s([[:alnum:]]+).*?,\s*(?:(\d+)x(\d+))(?:.*?DAR\s(\d+):(\d+))?(?:.*?(\d+)\s*kb\/s.*?([\d.]+)\s*fps)?/).map do |stream|
          Hash[[:map, :video_codec, :width, :height, :dar_width, :dar_height, :video_bitrate_in_kbps, :frame_rate].zip(stream)]
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

        # frame metadata
        s = Command.new(self.class.show_frames_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :stream => 'v', :input => input).capture
        @metadata[:interlaced] = true if s.include?('interlaced_frame=1')
      end
      @metadata
    end

    def video_stream
      metadata[:video_streams].first
    end

    def mean_volume
      @mean_volume ||= Command.new(Ffmpeg.volume_detect_command, :bin => Ffmpeg.bin, :input => input).capture.match(/mean_volume:\s([-\d.]+)\sdB/).to_a[1]
    end

    def select_outputs(outputs)
      outputs.select { |output| !output.path || output.path == input }
    end

    def output_groups(outputs)
      # qualities with the same group param are one group
      groups = Hash.new([])
      outputs.each { |output| groups[output.group] += [output] if output.group.present? }
      groups = groups.values 

      # qualities of one playlist are one group
      groups += outputs.select { |output| output.type == 'playlist' }.map { |playlist| playlist.output_group(outputs) }
      
      # other outputs are separate groups
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
      File.file?(input)
    end

  end
end
