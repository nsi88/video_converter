# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :bin, :ffprobe_bin, :options, :one_pass_command, :first_pass_command, :second_pass_command, :keyframes_command, :split_command, :concat_command
    end

    self.bin = '/usr/local/bin/ffmpeg'
    self.ffprobe_bin = '/usr/local/bin/ffprobe'
    self.options = {
      :codec => '-c',
      :video_codec => '-c:v',
      :audio_codec => '-c:a',
      :frame_rate => '-r',
      :keyint_min => '-keyint_min',
      :keyframe_interval => '-g',
      :force_keyframes => '-force_key_frames',
      :passlogfile => '-passlogfile',
      :video_bitrate => '-b:v',
      :audio_bitrate => '-b:a',
      :size => '-s',
      :video_filter => '-vf',
      :threads => '-threads',
      :format => '-f',
      :bitstream_format => '-bsf',
      :pixel_format => '-pix_fmt',
      :deinterlace => '-deinterlace',
      :map => '-map',
      :segment_time => '-segment_time',
      :reset_timestamps => '-reset_timestamps'
    }
    self.one_pass_command = '%{bin} -i %{input} -y %{options} %{output} 1>>%{log} 2>&1 || exit 1'
    self.first_pass_command = '%{bin} -i %{input} -y -pass 1 -an %{options} /dev/null 1>>%{log} 2>&1 || exit 1'
    self.second_pass_command = '%{bin} -i %{input} -y -pass 2 %{options} %{output} 1>>%{log} 2>&1 || exit 1'
    self.keyframes_command = '%{ffprobe_bin} -show_frames -select_streams v:0 -print_format csv %{input} | grep frame,video,1 | cut -d\',\' -f5 | tr "\n" "," | sed \'s/,$//\''
    self.split_command = '%{bin} -fflags +genpts -i %{input} -segment_time %{segment_time} -reset_timestamps 1 -c copy -map 0 -f segment %{output} 1>>%{log} 2>&1 || exit 1'
    self.concat_command = "%{bin} -f concat -i %{input} -c %{codec} %{output} 1>>%{log} 2>&1 || exit 1"

    attr_accessor :input, :group

    def initialize input, group
      self.input = input
      self.group = group
    end

    def run
      success = true
      threads = []
      common_first_pass = false
      
      qualities = group.select { |output| output.type != 'playlist' }
      # if all qualities in group contain one_pass, use one_pass_command for ffmpeg
      unless one_pass = qualities.inject { |r, q| r && q.one_pass }
        # if group qualities have different sizes use force_keyframes and separate first passes
        if common_first_pass = qualities.map { |quality| quality.height }.uniq.count == 1
          # first pass is executed with the best group quality, defined by bitrate or size
          best_quality = qualities.sort do |q1, q2| 
            res = q1.video_bitrate.to_i <=> q2.video_bitrate.to_i
            res = q1.height.to_i <=> q2.height.to_i if res == 0
            res = q1.width.to_i <=> q2.width.to_i if res == 0
            res
          end.last
          success &&= Command.new(self.class.first_pass_command, prepare_params(input, best_quality)).execute
        end
      end
      qualities.each do |output|
        command = if one_pass
          self.class.one_pass_command
        elsif !common_first_pass
          Command.chain(self.class.first_pass_command, self.class.second_pass_command)
        else
          self.class.second_pass_command
        end
        command = Command.new(command, prepare_params(input, output))
        if VideoConverter.paral
          threads << Thread.new { success &&= command.execute }
        else
          success &&= command.execute
        end
      end
      threads.each { |t| t.join } if VideoConverter.paral
      success
    end

    def split
      Command.new(self.class.split_command, prepare_params(input, group.first)).execute
    end

    def concat
      output = group.first
      output.codec ||= 'copy'
      Command.new(self.class.concat_command, prepare_params(input, output)).execute
    end

    private 

    def prepare_params input, output
      output.video_filter = []
      output.video_filter << "scale=#{output.width}:trunc\\(ow/a/2\\)*2" if output.width && !output.height
      output.video_filter << "scale=trunc\\(oh*a/2\\)*2:#{output.height}" if output.height && !output.width
      output.video_filter << { 90 => 'transpose=2', 180 => 'transpose=2,transpose=2', 270 => 'transpose=1' }[output.rotate] if output.rotate
      output.video_filter = output.video_filter.join(',')

      {
        :bin => self.class.bin,
        :input => input.to_s,
        :log => output.log,
        :output => output.ffmpeg_output,
        :codec => output.codec,
        :segment_time => output.segment_time,
        :options => self.class.options.map do |output_option, ffmpeg_option|
          if output.send(output_option).present?
            if output.send(output_option) == true
              ffmpeg_option
            else
              ffmpeg_option + ' ' + output.send(output_option).to_s
            end
          end
        end.join(' ')
      }
    end
  end
end
