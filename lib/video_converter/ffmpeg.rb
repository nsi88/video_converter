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
    
    self.one_pass_command = "%{bin} -i %{input} -y -acodec copy -vcodec %{video_codec} -g 100 -keyint_min 50 -b:v %{video_bitrate}k -bt %{video_bitrate}k %{vf} %{frame_rate} -f mp4 %{local_path} 1>%{log} 2>&1 || exit 1"

    self.first_pass_command = "%{bin} -i %{input} -y -an -vcodec %{video_codec} -g %{keyframe_interval} -keyint_min 25 -pass 1 -passlogfile %{passlogfile} -b:v 700k %{vf} %{frame_rate} -threads %{threads} -f mp4 /dev/null 1>>%{log} 2>&1 || exit 1"

    self.second_pass_command = "%{bin} -i %{input} -y -pass 2 -passlogfile %{passlogfile} -c:a %{audio_codec} -b:a %{audio_bitrate}k -c:v %{video_codec} -g %{keyframe_interval} -keyint_min 25 %{frame_rate} -b:v %{video_bitrate}k %{vf} -threads %{threads} -f mp4 %{local_path} 1>%{log} 2>&1 || exit 1"

    attr_accessor :input_array, :output_array, :one_pass, :paral, :log

    def initialize params
      [:input_array, :output_array].each do |param|
        self.send("#{param}=", params[param]) or raise ArgumentError.new("#{param} is needed")
      end
      [:one_pass, :paral, :log].each do |param|
        self.send("#{param}=", params[param] ? params[param] : self.class.send(param))
      end
    end

    def run
      res = true
      input_array.inputs.each do |input|
        threads = []
        input.output_groups.each_with_index do |group, group_number|
          passlogfile = File.join(File.dirname(group.first.local_path), "#{group_number}.log")
          one_pass = self.one_pass || group.first.video_codec == 'copy'
          unless one_pass
            first_pass_command = Command.new self.class.first_pass_command, prepare_params(common_params.merge(group.first.to_hash).merge((group.first.playlist.to_hash rescue {})).merge(:passlogfile => passlogfile, :input => input))
            res &&= first_pass_command.execute
          end
          group.each do |quality|
            if one_pass
              quality_command = Command.new self.class.one_pass_command, prepare_params(common_params.merge(quality.to_hash).merge(:passlogfile => passlogfile, :input => input))
            else
              quality_command = Command.new self.class.second_pass_command, prepare_params(common_params.merge(quality.to_hash).merge(:passlogfile => passlogfile, :input => input))
            end
            if paral
              threads << Thread.new { res &&= quality_command.execute }
            else
              res &&= quality_command.execute
            end
          end
        end
        threads.each { |t| t.join } if paral
      end
      res
    end

    private 

    def common_params
      { :bin => self.class.bin, :log => log }
    end

    def prepare_params params
      width = params[:width] || params[:size].to_s.match(/^(\d+)x(\d*)$/).to_a[1] || -1
      height = params[:height] || params[:size].to_s.match(/^(\d*)x(\d+)$/).to_a[2] || -1
      if width == -1 && height == -1
        params[:vf] = ''
      else
        params[:vf] = "-vf scale=#{width}:#{height}"
      end
      params[:frame_rate] = params[:frame_rate] ? "-r #{params[:frame_rate]}" : ''
      params
    end
  end
end
