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
    
    self.one_pass_command = "%{bin} -i %{input} -y -acodec copy -vcodec %{video_codec} -g 100 -keyint_min 50 -b:v %{video_bitrate}k -bt %{video_bitrate}k %{vf} %{frame_rate} -progress %{progressfile} -f mp4 %{local_path} 1>%{log} 2>&1 || exit 1"

    self.first_pass_command = "%{bin} -i %{input} -y -an -vcodec %{video_codec} -g %{keyframe_interval} -keyint_min 25 -pass 1 -passlogfile %{passlogfile} -progress %{progressfile} -b:v 3000k %{vf} %{frame_rate} -threads %{threads} -pix_fmt yuv420p -f mp4 /dev/null 1>>%{log} 2>&1 || exit 1"

    self.second_pass_command = "%{bin} -i %{input} -y -pass 2 -passlogfile %{passlogfile} -progress %{progressfile} -c:a %{audio_codec} -b:a %{audio_bitrate}k -ac 2 -c:v %{video_codec} -g %{keyframe_interval} -keyint_min 25 %{frame_rate} -b:v %{video_bitrate}k %{vf} -threads %{threads} -pix_fmt yuv420p -f mp4 %{local_path} 1>%{log} 2>&1 || exit 1"

    attr_accessor :input_array, :output_array, :one_pass, :paral, :log, :process

    def initialize params
      [:input_array, :output_array].each do |param|
        self.send("#{param}=", params[param]) or raise ArgumentError.new("#{param} is needed")
      end
      [:one_pass, :paral, :log, :process].each do |param|
        self.send("#{param}=", params[param] ? params[param] : self.class.send(param))
      end
    end

    def run
      progress_thread = Thread.new { collect_progress }
      res = true
      input_array.inputs.each do |input|
        threads = []
        input.output_groups.each_with_index do |group, group_number|
          passlogfile = File.join(group.first.work_dir, "#{group_number}.log")
          progressfile = File.join(process.progress_dir, "#{group_number}.log")
          one_pass = self.one_pass || group.first.video_codec == 'copy'
          unless one_pass
            first_pass_command = Command.new self.class.first_pass_command, prepare_params(common_params.merge((group.first.playlist.to_hash rescue {})).merge(group.first.to_hash).merge(:passlogfile => passlogfile, :input => input, :progressfile => progressfile))
            res &&= first_pass_command.execute
          end
          group.each_with_index do |quality, quality_number|
            progressfile = File.join(process.progress_dir, "#{group_number}_#{quality_number}.log")
            if one_pass
              quality_command = Command.new self.class.one_pass_command, prepare_params(common_params.merge(quality.to_hash).merge(:passlogfile => passlogfile, :input => input, :progressfile => progressfile))
            else
              quality_command = Command.new self.class.second_pass_command, prepare_params(common_params.merge(quality.to_hash).merge(:passlogfile => passlogfile, :input => input, :progressfile => progressfile))
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
      progress_thread.kill
      res
    end
    
    private 

    def common_params
      { :bin => self.class.bin, :log => log }
    end

    def prepare_params params
      width = params[:width] || params[:size].to_s.match(/^(\d+)x(\d*)$/).to_a[1] || 'trunc(oh*a/2)*2'
      height = params[:height] || params[:size].to_s.match(/^(\d*)x(\d+)$/).to_a[2] || 'trunc(ow/a/2)*2'
      if width.to_s.include?('trunc') && height.to_s.include?('trunc')
        params[:vf] = ''
      else
        params[:vf] = "-vf scale=#{width}:#{height}"
      end
      params[:frame_rate] = params[:frame_rate] ? "-r #{params[:frame_rate]}" : ''
      params
    end

    def processes_count
      (one_pass ? 0 : input_array.inputs.inject(0) { |sum, i| sum + i.output_groups.count }) +
      input_array.inputs.map { |i| i.output_groups.map { |g| g.count } }.flatten.inject(:+)
    end

    def collect_progress
      duration = input_array.inputs.first.metadata[:duration_in_ms]
      loop do
        sleep Process.collect_progress_interval
        koefs = []
        Dir.glob(File.join(process.progress_dir, '*.log')).each do |progressfile|
          if matches = `tail -n 9 #{progressfile}`.match(/out_time_ms=(\d+).*?progress=(\w+)/m)
            koefs << (matches[2] == 'end' ? 1 : (matches[1].to_f / 1000 / duration))
          end
        end
        process.collect_progress(koefs.inject { |sum, k| sum + k } / processes_count)
      end
    end
  end
end
