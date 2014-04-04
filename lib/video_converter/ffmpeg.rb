# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :bin, :ffprobe_bin, :options, :one_pass_command, :first_pass_command, :second_pass_command
    end

    self.bin = '/usr/local/bin/ffmpeg'
    self.ffprobe_bin = '/usr/local/bin/ffprobe'
    self.options = {
      :video_codec => '-c:v',
      :audio_codec => '-c:a',
      :keyframe_interval => '-g',
      :passlogfile => '-passlogfile',
      :video_bitrate => '-b:v',
      :audio_bitrate => '-b:a',
      :video_filter => '-vf',
      :frame_rate => '-r',
      :threads => '-threads',
      :format => '-f',
      :bitstream_format => '-bsf'
    }
    self.one_pass_command = '%{bin} -i %{input} -y %{options} %{output} 1>>%{log} 2>&1 || exit 1'
    self.first_pass_command = '%{bin} -i %{input} -y -pass 1 -an -keyint_min 25 -pix_fmt yuv420p %{options} /dev/null 1>>%{log} 2>&1 || exit 1'
    self.second_pass_command = '%{bin} -i %{input} -y -pass 2 -keyint_min 25 -pix_fmt yuv420p %{options} %{output} 1>>%{log} 2>&1 || exit 1'

    attr_accessor :inputs, :outputs

    def initialize inputs, outputs
      self.inputs = inputs
      self.outputs = outputs
    end

    # NOTE outputs of one group must have common first pass
    def run
      success = true
      threads = []
      inputs.each do |input|
        input.output_groups.each do |group|
          qualities = group.select { |output| output.type != 'playlist' }
          # NOTE if all qualities in group contain one_pass, use one_pass_command for ffmpeg
          unless one_pass = qualities.inject { |r, q| r && q.one_pass }
            # NOTE first pass is executed with maximal group's video bitrate
            best_quality = qualities.sort { |q1, q2| q1.video_bitrate.to_i <=> q2.video_bitrate.to_i }.last
            success &&= Command.new(self.class.first_pass_command, prepare_params(input, best_quality)).execute
          end
          qualities.each do |output|
            command = Command.new(one_pass ? self.class.one_pass_command : self.class.second_pass_command, prepare_params(input, output))
            if VideoConverter.paral
              threads << Thread.new { success &&= command.execute }
            else
              success &&= command.execute
            end
          end
        end
      end
      threads.each { |t| t.join } if VideoConverter.paral
      success
    end

    private 

    def prepare_params input, output
      output.video_filter = []
      if output.size
        output.video_filter << "scale=#{output.size.sub('x', ':')}"
      elsif output.width && output.size
        output.video_filter << "scale=#{output.width}:#{output.height}"
      elsif output.width
        output.video_filter << "scale=#{output.width}:trunc\\(ow/a/2\\)*2"
      elsif output.height
        output.video_filter << "scale=trunc\\(oh*a/2\\)*2:#{output.height}"
      end
      output.video_filter << { 90 => 'transpose=2', 180 => 'transpose=2,transpose=2', 270 => 'transpose=1' }[output.rotate] if output.rotate
      output.video_filter = output.video_filter.join(',')

      {
        :bin => self.class.bin,
        :input => input.to_s,
        :log => output.log,
        :output => output.ffmpeg_output,
        :options => self.class.options.map do |output_option, ffmpeg_option|
          if output.send(output_option).present?
            ffmpeg_option += ' ' + output.send(output_option).to_s
          end
        end.join(' ')
      }
    end
  end
end
