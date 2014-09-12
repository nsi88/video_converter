# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :aliases, :bin, :ffprobe_bin
      attr_accessor :one_pass_command, :first_pass_command, :second_pass_command, :keyframes_command, :split_command, :concat_command, :mux_command
    end

    self.aliases = {
      :codec => 'c',
      :video_codec => 'c:v',
      :audio_codec => 'c:a',
      :frame_rate => 'r',
      :keyframe_interval => 'g',
      :video_bitrate => 'b:v',
      :audio_bitrate => 'b:a',
      :size => 's',
      :format => 'f',
      :bitstream_format => 'bsf',
      :pixel_format => 'pix_fmt'
    }
    self.bin = '/usr/local/bin/ffmpeg'
    self.ffprobe_bin = '/usr/local/bin/ffprobe'
    
    self.one_pass_command = '%{bin} -i %{input} %{watermark} -y %{options} %{output} 1>>%{log} 2>&1 || exit 1'
    self.first_pass_command = '%{bin} -i %{input} %{watermark} -y -pass 1 -an %{options} /dev/null 1>>%{log} 2>&1 || exit 1'
    self.second_pass_command = '%{bin} -i %{input} %{watermark} -y -pass 2 %{options} %{output} 1>>%{log} 2>&1 || exit 1'
    self.keyframes_command = '%{ffprobe_bin} -show_frames -select_streams v:0 -print_format csv %{input} | grep frame,video,1 | cut -d\',\' -f5 | tr "\n" "," | sed \'s/,$//\''
    self.split_command = '%{bin} -fflags +genpts -i %{input} %{options} %{output} 1>>%{log} 2>&1 || exit 1'
    self.concat_command = "%{bin} -f concat -i %{input} %{options} %{output} 1>>%{log} 2>&1 || exit 1"
    self.mux_command = "%{bin} %{inputs} %{maps} %{options} %{output} 1>>%{log} 2>&1 || exit 1"

    def self.split(input, output)
      output.options = { :format => 'segment', :map => 0, :codec => 'copy' }.merge(output.options)
      Command.new(split_command, prepare_params(input, output)).execute
    end
    
    def self.concat(inputs, output, method = nil)
      method = %w(ts mpg mpeg).include?(File.extname(inputs.first.to_s).delete('.')) ? :protocol : :muxer unless method
      output.options = { :codec => 'copy' }.merge(output.options)
      send("concat_#{method}", inputs, output)
    end

    def self.mux(inputs, output)
      output.options = { :codec => 'copy' }.merge(output.options)
      Command.new(mux_command, prepare_params(nil, output).merge({
        :inputs => inputs.map { |i| "-i #{i}" }.join(' '),
        :maps => inputs.each_with_index.map { |_,i| "-map #{i}:0" }.join(' ')
      })).execute
    end
    
    attr_accessor :input, :outputs

    def initialize input, outputs
      self.input = input      
      self.outputs = input.select_outputs(outputs)

      self.outputs.each do |output|
        # autorotate
        if output.type != 'playlist' && [nil, true].include?(output.rotate) && input.metadata[:rotate]
          output.rotate = 360 - input.metadata[:rotate]
        end
        # autodeinterlace
        output.options[:deinterlace] = input.metadata[:interlaced] if output.options[:deinterlace].nil?
        # filter_complex
        filter_complex = [output.options[:filter_complex]].compact
        filter_complex << "crop=#{output.crop}" if output.crop
        if output.width || output.height
          video_stream = input.metadata[:video_streams].first
          output.width = (output.height * video_stream[:width].to_f / video_stream[:height].to_f / 2).to_i * 2 if output.height && !output.width
          output.height = (output.width * video_stream[:height].to_f / video_stream[:width].to_f / 2).to_i * 2 if output.width && !output.height
          filter_complex << "scale=#{scale(output.width, :w)}:#{scale(output.height, :h)}"
        end
        if output.watermarks && (output.watermarks[:width] || output.watermarks[:height])
          filter_complex = ["[0:v] #{filter_complex.join(',')} [main]"]
          filter_complex << "[1:v] scale=#{scale(output.watermarks[:width], :w, output.width)}:#{scale(output.watermarks[:height], :h, output.height)} [overlay]"
          filter_complex << "[main] [overlay] overlay=#{overlay(output.watermarks[:x], :w)}:#{overlay(output.watermarks[:y], :h)}"
          if output.rotate
            filter_complex[filter_complex.count-1] += ' [overlayed]'
            filter_complex << '[overlayed] ' + rotate(output.rotate)
          end
          output.options[:filter_complex] = "'#{filter_complex.join(';')}'"
        else
          filter_complex << "overlay=#{overlay(output.watermarks[:x], :w)}:#{overlay(output.watermarks[:y], :h)}" if output.watermarks
          filter_complex << rotate(output.rotate) if output.rotate
          output.options[:filter_complex] = filter_complex.join(',') if filter_complex.any?
        end

        output.options[:format] ||= File.extname(output.filename).delete('.')
        output.options = { 
          :threads => 1, 
          :video_codec => 'libx264', 
          :audio_codec => 'libfaac', 
          :pixel_format => 'yuv420p' 
        }.merge(output.options) unless output.type == 'playlist'
      end
    end

    def run
      success = true
      threads = []

      input.output_groups(outputs).each_with_index do |group, group_index|
        qualities = group.select { |output| output.type != 'playlist' }

        # common first pass
        if !one_pass?(qualities) && common_first_pass?(qualities)
          qualities.each do |output| 
            output.options[:passlogfile] = File.join(output.work_dir, "group#{group_index}.log")
            output.options[:keyint_min] = 25
            output.options[:keyframe_interval] = 100
          end
          best_quality = qualities.sort do |q1, q2|
            res = q1.options[:video_bitrate].to_i <=> q2.options[:video_bitrate].to_i
            res = q1.height.to_i <=> q2.height.to_i if res == 0
            res = q1.width.to_i <=> q2.width.to_i if res == 0
            # TODO compare by size
            res
          end.last
          success &&= Command.new(self.class.first_pass_command, self.class.prepare_params(input, best_quality)).execute
        end

        qualities.each_with_index do |output, output_index|
          command = if one_pass?(qualities)
            self.class.one_pass_command
          elsif common_first_pass?(qualities)
            self.class.second_pass_command
          else
            output.options[:passlogfile] = File.join(output.work_dir, "group#{group_index}_#{output_index}.log")
            output.options[:force_key_frames] = (input.metadata[:duration_in_ms] / 1000.0 / Output.keyframe_interval_in_seconds).ceil.times.to_a.map { |t| t * Output.keyframe_interval_in_seconds }.join(',')
            Command.chain(self.class.first_pass_command, self.class.second_pass_command)
          end

          # run ffmpeg
          command = Command.new(command, self.class.prepare_params(input, output))
          if VideoConverter.paral
            threads << Thread.new { success &&= command.execute }
          else
            success &&= command.execute
          end
        end
      end
      threads.each { |t| t.join } if VideoConverter.paral
      success
    end

    private 

    def self.concat_muxer(inputs, output)
      list = File.join(output.work_dir, 'list.txt')
      # NOTE ffmpeg concat list requires unescaped files
      File.write(list, inputs.map { |input| "file '#{File.absolute_path(input.unescape)}'" }.join("\n"))
      success = Command.new(concat_command, prepare_params(list, output)).execute
      FileUtils.rm list if success
      success
    end

    def self.concat_protocol(inputs, output)
      Command.new(one_pass_command, prepare_params('"concat:' + inputs.join('|') + '"', output)).execute
    end

    def common_first_pass?(qualities)
      # if group qualities have different sizes use force_key_frames and separate first passes
      qualities.uniq { |o| o.height }.count == 1 && qualities.uniq { |o| o.width }.count == 1 && qualities.uniq { |o| o.options[:size] }.count == 1
    end

    def one_pass?(qualities)
      qualities.inject(true) { |r, q| r && q.one_pass }
    end

    def self.prepare_params input, output
      
      {
        :bin => bin,
        :input => input.to_s,
        :watermark => (output.watermarks ? '-i ' + output.watermarks[:url] : ''),
        :options => output.options.map do |option, values|
          unless output.respond_to?(option)
            option = '-' + (aliases[option] || option).to_s
            Array.wrap(values).map do |value|
              value == true ? option : "#{option} #{value}"
            end.join(' ')
          end
        end.compact.join(' '),
        :output => output.ffmpeg_output,
        :log => output.log
      }
    end

    def scale(size, wh, percent_of = nil)
      if size.to_s.end_with?('%')
        percent_of ? (percent_of * size.to_f / 100).to_i : "i#{wh}*#{size.to_f/100}"
      else
        size || "trunc\\(o#{{:h => :w, :w => :h}[wh]}/a/2\\)*2"
      end
    end

    def overlay(xy, wh)
      if xy.to_s.end_with?('%')
        xy = xy.to_f / 100
        xy < 0 ? "main_#{wh}*#{1 + xy}-overlay_#{wh}" : "main_#{wh}*#{xy}"
      else
        xy.to_i < 0 ? "main_#{wh}-overlay_#{wh}#{xy}" : xy.to_i
      end
    end

    def rotate(angle)
      { 90 => 'transpose=2', 180 => 'transpose=2,transpose=2', 270 => 'transpose=1' }[angle]
    end
  end
end
