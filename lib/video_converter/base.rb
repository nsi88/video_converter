# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input_array, :output_array, :log, :uid, :clear_tmp, :process

    def initialize params
      self.uid = params[:uid] || (Socket.gethostname + object_id.to_s)
      self.output_array = OutputArray.new(params[:output] || {}, uid)
      self.input_array = InputArray.new(params[:input], output_array)
      input_array.inputs.each { |input| raise ArgumentError.new("#{input} does not exist") unless input.exists? }
      if params[:log].nil?
        self.log = '/dev/null'
      else
        self.log = params[:log]
        FileUtils.mkdir_p File.dirname(log)
      end
      self.clear_tmp = params[:clear_tmp].nil? ? true : params[:clear_tmp]
    end

    def run
      self.process = VideoConverter::Process.new(uid, output_array)
      [:convert, :segment, :screenshot].each do |action|
        process.status = action.to_s
        process.status = "#{action}_error" and return false unless send(action)
      end
      process.status = 'finished'
      clear if clear_tmp
      true
    end

    private

    def convert
      params = {}
      [:input_array, :output_array, :log, :process].each do |param|
        params[param] = self.send(param)
      end
      Ffmpeg.new(params).run
    end

    def segment
      params = {}
      [:output_array, :log].each do |param|
        params[param] = self.send(param)
      end
      LiveSegmenter.new(params).run
    end

    def screenshot
      output_array.outputs.each do |output|
        output.thumbnails.to_a.each do |thumbnail_params|
          VideoScreenshoter.new(thumbnail_params.merge(:ffmpeg => Ffmpeg.bin, :input => File.join(output.work_dir, output.filename.sub(/\.m3u8/, '.ts')), :output_dir => File.join(output.work_dir, 'thumbnails'))).make_screenshots
        end
      end
      true
    end

    def clear
      output_array.outputs.each do |output|
        FileUtils.rm(Dir.glob(File.join(output.work_dir, '*.log')))
        FileUtils.rm(Dir.glob(File.join(output.work_dir, '*.log.mbtree')))
        FileUtils.rm(File.join(output.work_dir, output.filename.sub(/\.m3u8$/, '.ts'))) if output.type == :segmented
      end
      FileUtils.rm_r(process.process_dir)
      true
    end
  end
end
