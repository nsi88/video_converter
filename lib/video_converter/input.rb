# encoding: utf-8

module VideoConverter
  class Input
    class << self
      attr_accessor :metadata_command
    end

    self.metadata_command = "%{bin} -i %{input} 2>&1"

    attr_accessor :input, :outputs, :output_groups

    def initialize input
      raise ArgumentError.new('input is needed') if input.nil? || input.empty?
      self.input = input
      self.outputs = []
      self.output_groups = []
    end

    def to_s
      input.gsub(/ /, "\\ ")
    end

    def exists?
      if is_http?
        url = URI.parse(input)
        Net::HTTP.start(url.host) do |http|
          response = http.request_head url.path
          Net::HTTPSuccess === response
        end
      elsif is_local?
        File.file? input
      else
        false
      end
    end

    def metadata
      metadata = {}
      s = `#{Command.new self.class.metadata_command, common_params}`
      if (m = s.match(/Stream.*?Audio:\s*(\w+).*?(\d+)\s*Hz.*?(\d+)\s*kb\/s$/).to_a).any?
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
          metadata[:file_size_in_bytes] = File.size(input)
        end
        metadata[:format] = File.extname(input).sub('.', '')
      end
      metadata
    end

    def is_http?
      !!input.match(/^http:\/\//)
    end

    def is_local?
      File.file?(input)
    end

    private

    def common_params
      { :bin => VideoConverter::Ffmpeg.bin, :input => to_s }
    end
  end
end
