# encoding: utf-8

module VideoConverter
  class Input
    class << self
      attr_accessor :metadata_command
    end

    self.metadata_command = "%{ffprobe_bin} %{input} 2>&1"

    attr_accessor :input, :output_groups, :metadata

    def initialize input, outputs = []
      raise ArgumentError.new('input is needed') if input.blank?
      self.input = input
      raise ArgumentError.new("#{input} does not exist") unless exists?

      # for many inputs case take outputs for this input
      outputs = outputs.select { |output| !output.path || output.path == input.to_s }
      self.output_groups = []
      
      # qualities with the same playlist is a one group
      outputs.select { |output| output.type == 'playlist' }.each_with_index do |playlist, index|
        paths = playlist.streams.map { |stream| stream[:path] }
        output_group = outputs.select { |output| paths.include?(output.filename) }
        if output_group.any?
          output_group.each { |output| output.passlogfile = File.join(output.work_dir, "group#{index}.log") unless output.one_pass }
          self.output_groups << output_group.unshift(playlist) 
        end
      end
      # qualities without playlist are separate groups
      (outputs - output_groups.flatten).each { |output| self.output_groups << [output] }
      self.metadata = get_metadata
      
      # autorotate
      outputs.each do |output|
        if output.type != 'playlist' && [nil, true].include?(output.rotate) && metadata[:rotate]
          output.rotate = 360 - metadata[:rotate]
        end
      end
    end

    def to_s
      input
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

    def get_metadata
      metadata = {}
      s = `#{Command.new self.class.metadata_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :input => input}`.encode!('UTF-8', 'UTF-8', :invalid => :replace)
      if m = s.match(/Stream.*?Audio:\s*(\w+).*?(\d+)\s*Hz.*?(\d+)\s*kb\/s.*?$/)
        metadata[:audio_codec] = m[1]
        metadata[:audio_sample_rate] = m[2].to_i
        metadata[:audio_bitrate_in_kbps] = m[3].to_i
      end
      metadata[:channels] = s.scan(/Stream #\d+:\d+/).count
      if m = s.match(/Duration:\s+(\d+):(\d+):([\d.]+).*?bitrate:\s*(\d+)\s*kb\/s/)
        metadata[:duration_in_ms] = ((m[1].to_i * 3600 + m[2].to_i * 60 + m[3].to_f) * 1000).to_i
        metadata[:total_bitrate_in_kbps] = m[4].to_i
      end
      if m = s.match(/Stream.*?Video:\s(\S+).*?,\s*((\d+)x(\d+)).*?(\d+)\s*kb\/s.*?([\d.]+)\s*fps/)
        metadata[:video_codec] = m[1]
        metadata[:width] = m[3].to_i
        metadata[:height] = m[4].to_i
        metadata[:video_bitrate_in_kbps] = m[5].to_i
        metadata[:frame_rate] = m[6].to_f
      end
      if m = s.match(/rotate\s*\:\s*(\d+)/)
        metadata[:rotate] = m[1].to_i
      end
      if is_http?
        url = URI.parse(input)
        Net::HTTP.start(url.host) do |http|
          response = http.request_head url.path
          metadata[:file_size_in_bytes] = response['content-length'].to_i
        end
      elsif is_local?
        metadata[:file_size_in_bytes] = File.size(input.gsub('\\', ''))
      end
      metadata[:format] = File.extname(input).delete('.')
      metadata
    end
  end
end
