# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :bin, :one_pass, :one_pass_command, :first_pass_command, :second_pass_command, :metadata_command
    end

    self.bin = '/usr/local/bin/ffmpeg'

    self.one_pass = false
    
    self.one_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -b:v %{bitrate}k -bt %{bitrate}k -threads %{threads} -f mp4 %{file} 1>%{log} 2>&1 || exit 1"

    self.first_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -an -vcodec libx264 -g 100 -keyint_min 50 -pass 1 -passlogfile %{input}.log -b:v 700k -bt 700k -threads %{threads} -f mp4 /dev/null  1>>%{log} 2>&1 || exit 1"

    self.second_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -pass 2 -passlogfile %{input}.log -b:v %{bitrate}k -bt %{bitrate}k -threads %{threads} -f mp4 %{file} 1>%{log} 2>&1 || exit 1"

    self.metadata_command = "%{bin} -i %{input} 2>&1"

    attr_accessor :input, :profile, :one_pass, :paral, :log

    def initialize params
      params.each do |param, value|
        self.send("#{param}=", value)
      end
    end

    def run
      res = true
      threads = []
      Profile.groups(profile).each do |qualities|
        unless one_pass
          group_command = Command.new self.class.first_pass_command, common_params.merge(qualities.first.to_hash)
          res &&= group_command.execute
        end
        qualities.each do |quality|
          if one_pass
            quality_command = Command.new self.class.one_pass_command, common_params.merge(quality.to_hash)
          else
            quality_command = Command.new self.class.second_pass_command, common_params.merge(quality.to_hash)
          end
          if paral
            threads << Thread.new { res &&= quality_command.execute }
          else
            res &&= quality_command.execute
          end
        end
      end
      threads.each { |t| t.join } if paral
      res
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
        if is_url?
          url = URI.parse(input)
          Net::HTTP.start(url.host) do |http|
            response = http.request_head url.path
            metadata[:file_size_in_bytes] = response['content-length'].to_i
            puts response['content-type']
          end
        elsif is_local?
          metadata[:file_size_in_bytes] = File.size(input)
        end
        metadata[:format] = File.extname(input).sub('.', '')
      end
      metadata
    end

    private 

    def common_params
      { :bin => self.class.bin, :input => input, :log => log }
    end

    def is_url?
      !!input.match(/^http:\/\//)
    end

    def is_local?
      File.file?(input)
    end
  end
end
