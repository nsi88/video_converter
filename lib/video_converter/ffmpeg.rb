# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :bin, :one_pass, :paral, :log, :one_pass_command, :first_pass_command, :second_pass_command
    end

    self.bin = '/usr/local/bin/ffmpeg'
    self.one_pass = false
    self.paral = true
    self.log = '/dev/null'
    
    self.one_pass_command = "%{bin} -i %{input} -y -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -b:v %{video_bitrate}k -bt %{video_bitrate}k -f mp4 %{local_path} 1>%{log} 2>&1 || exit 1"

    self.first_pass_command = "%{bin} -i %{input} -y -an -vcodec libx264 -g %{keyframe_interval} -keyint_min 25 -pass 1 -passlogfile %{passlogfile} -b:v 700k -threads %{threads} -f mp4 /dev/null 1>>%{log} 2>&1 || exit 1"

    self.second_pass_command = "%{bin} -i %{input} -y -pass 2 -passlogfile %{passlogfile} -c:a libfaac -b:a %{audio_bitrate}k -c:v libx264 -g %{keyframe_interval} -keyint_min 25 %{frame_rate} -b:v %{video_bitrate}k %{size} -threads %{threads} -f mp4 %{local_path} 1>%{log} 2>&1 || exit 1"

    attr_accessor :input, :output_array, :one_pass, :paral, :log

    def initialize params
      [:input, :output_array].each do |param|
        self.send("#{param}=", params[param]) or raise ArgumentError.new("#{param} is needed")
      end
      [:one_pass, :paral, :log].each do |param|
        self.send("#{param}=", params[param] ? params[param] : self.class.send(param))
      end
    end

    def run
      res = true
      threads = []
      output_array.groups.each_with_index do |group, group_number|
        passlogfile = File.join(File.dirname(group.first.local_path), "#{group_number}.log")
        unless one_pass
          first_pass_command = Command.new self.class.first_pass_command, prepare_params(common_params.merge(group.first.to_hash).merge((group.first.playlist.to_hash rescue {})).merge(:passlogfile => passlogfile))
          res &&= first_pass_command.execute
        end
        group.each do |quality|
          if one_pass
            quality_command = Command.new self.class.one_pass_command, prepare_params(common_params.merge(quality.to_hash).merge(:passlogfile => passlogfile))
          else
            quality_command = Command.new self.class.second_pass_command, prepare_params(common_params.merge(quality.to_hash).merge(:passlogfile => passlogfile))
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

    private 

    def common_params
      { :bin => self.class.bin, :input => input, :log => log }
    end

    def prepare_params params
      params[:size] = params[:size] ? "-s #{params[:size]}" : ''
      params[:frame_rate] = params[:frame_rate] ? "-r #{params[:frame_rate]}" : ''
      params
    end
  end
end
