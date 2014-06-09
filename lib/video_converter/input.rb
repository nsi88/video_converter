# encoding: utf-8

module VideoConverter
  class Input
    class << self
      attr_accessor :metadata_command, :show_frame_command
    end

    self.metadata_command = "%{ffprobe_bin} %{input} 2>&1"
    self.show_frame_command = "%{ffprobe_bin} -show_frames -select_streams v %{input} 2>/dev/null | head -n 24"

    attr_accessor :input, :output_groups, :metadata

    def initialize input, outputs = []
      raise ArgumentError.new('input is needed') if input.blank?
      self.input = input
      raise ArgumentError.new("#{input} does not exist") unless exists?
      self.metadata = get_metadata

      # for many inputs case take outputs for this input
      outputs = outputs.select { |output| !output.path || output.path == input.to_s }
      self.output_groups = []
      
      # qualities with the same playlist is a one group
      outputs.select { |output| output.type == 'playlist' }.each_with_index do |playlist, group_index|
        paths = playlist.streams.map { |stream| stream[:path] }
        output_group = outputs.select { |output| paths.include?(output.filename) }
        if output_group.any?
          # if group qualities have different sizes use force_keyframes and separate first passes
          common_first_pass = output_group.map { |output| output.height }.uniq.count == 1
          output_group.each_with_index do |output, output_index| 
            unless output.one_pass
              if common_first_pass
                output.passlogfile = File.join(output.work_dir, "group#{group_index}.log")
              else
                output.passlogfile = File.join(output.work_dir, "group#{group_index}_#{output_index}.log")
                output.force_keyframes = (metadata[:duration_in_ms] / 1000 / Output.keyframe_interval_in_seconds).times.to_a.map { |t| t * Output.keyframe_interval_in_seconds }.join(',')
                output.frame_rate = output.keyint_min = output.keyframe_interval = nil
              end
            end
          end
          self.output_groups << output_group.unshift(playlist) 
        end
      end
      # qualities without playlist are separate groups
      (outputs - output_groups.flatten).each { |output| self.output_groups << [output] }
      
      # set output parameters depending of input
      outputs.each do |output|
        # autorotate
        if output.type != 'playlist' && [nil, true].include?(output.rotate) && metadata[:rotate]
          output.rotate = 360 - metadata[:rotate]
        end
        # autodeinterlace
        output.deinterlace = metadata[:interlaced] if output.deinterlace.nil?
      end
    end

    def to_s
      input
    end

    def unescape
      input.gsub(/\\+([^n])/, '\1')
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
      # common metadata
      s = Command.new(self.class.metadata_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :input => input).capture
      if m = s.match(/Stream\s#(\d:\d).*?Audio:\s*(\w+).*?(\d+)\s*Hz.*?(\d+)\s*kb\/s.*?$/)
        metadata[:audio_stream] = m[1]
        metadata[:audio_codec] = m[2]
        metadata[:audio_sample_rate] = m[3].to_i
        metadata[:audio_bitrate_in_kbps] = m[4].to_i
      end
      metadata[:channels] = s.scan(/Stream #\d+:\d+/).count
      if m = s.match(/Duration:\s+(\d+):(\d+):([\d.]+).*?bitrate:\s*(\d+)\s*kb\/s/)
        metadata[:duration_in_ms] = ((m[1].to_i * 3600 + m[2].to_i * 60 + m[3].to_f) * 1000).to_i
        metadata[:total_bitrate_in_kbps] = m[4].to_i
      end
      if m = s.match(/Stream\s#(\d:\d).*?Video:\s(\S+).*?,\s*((\d+)x(\d+)).*?(\d+)\s*kb\/s.*?([\d.]+)\s*fps/)
        metadata[:video_stream] = m[1]
        metadata[:video_codec] = m[2]
        metadata[:width] = m[4].to_i
        metadata[:height] = m[5].to_i
        metadata[:video_bitrate_in_kbps] = m[6].to_i
        metadata[:frame_rate] = m[7].to_f
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

      # frame metadata
      s = Command.new(self.class.show_frame_command, :ffprobe_bin => Ffmpeg.ffprobe_bin, :input => input).capture
      metadata[:interlaced] = true if s.include?('interlaced_frame=1')

      metadata
    end
  end
end
