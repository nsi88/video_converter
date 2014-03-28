# encoding: utf-8

module VideoConverter
  class Input
    class << self
      attr_accessor :metadata_command
    end

    self.metadata_command = "%{ffprobe_bin} %{input} 2>&1"

    attr_accessor :input, :output_groups

    def initialize input, outputs = []
      raise ArgumentError.new('input is needed') if input.blank?
      self.input = input
      raise ArgumentError.new("#{input} does not exist") unless exists?

      self.output_groups = []
      outputs.select { |output| output.type == 'playlist' }.each_with_index do |playlist, index|
        paths = playlist.streams.map { |stream| stream[:path] }
        output_group = outputs.select { |output| paths.include?(output.filename) && (!output.path || output.path == input.to_s) }
        if output_group.any?
          output_group.each { |output| output.passlogfile = File.join(output.work_dir, "group#{index}.log") }
          self.output_groups << output_group.unshift(playlist) 
        end
      end
    end

    def to_s
      input
    end

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

    def metadata
      metadata = {}
      s = `#{Command.new self.class.metadata_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :input => input}`.encode!('UTF-8', 'UTF-8', :invalid => :replace)
      if (m = s.match(/Stream.*?Audio:\s*(\w+).*?(\d+)\s*Hz.*?(\d+)\s*kb\/s.*?$/).to_a).any?
        metadata[:audio_codec] = m[1]
        metadata[:audio_sample_rate] = m[2].to_i
        metadata[:audio_bitrate_in_kbps] = m[3].to_i
      end
      if (m = s.scan(/Stream #\d+:\d+/)).any?
        metadata[:channels] = m.count
      end
      if (m = s.match(/Duration:\s+(\d+):(\d+):([\d.]+).*?bitrate:\s*(\d+)\s*kb\/s/).to_a).any?
        metadata[:duration_in_ms] = ((m[1].to_i * 3600 + m[2].to_i * 60 + m[3].to_f) * 1000).to_i
        metadata[:total_bitrate_in_kbps] = m[4].to_i
      end
      if (m = s.match(/Stream.*?Video:\s(\S+).*?,\s*((\d+)x(\d+)).*?(\d+)\s*kb\/s.*?([\d.]+)\s*fps/).to_a).any?
        metadata[:video_codec] = m[1]
        metadata[:width] = m[3].to_i
        metadata[:height] = m[4].to_i
        metadata[:video_bitrate_in_kbps] = m[5].to_i
        metadata[:frame_rate] = m[6].to_f
      end
      if metadata.any?
        if is_http?
          url = URI.parse(input)
          Net::HTTP.start(url.host) do |http|
            response = http.request_head url.path
            metadata[:file_size_in_bytes] = response['content-length'].to_i
          end
        elsif is_local?
          metadata[:file_size_in_bytes] = File.size(input.gsub('\\', ''))
        end
        metadata[:format] = File.extname(input).sub('.', '')
      end
      metadata
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
