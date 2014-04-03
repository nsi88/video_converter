# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :uid, :outputs, :inputs, :clear_tmp

    def initialize params
      self.uid = params[:uid] || (Socket.gethostname + object_id.to_s)
      self.outputs = Array.wrap(params[:output] || params[:outputs]).map do |output| 
        Output.new(output.merge(:uid => uid))
      end
      self.inputs = Array.wrap(params[:input] || params[:inputs]).map do |input|
        Input.new(input, outputs)
      end
      self.clear_tmp = params[:clear_tmp].nil? ? true : params[:clear_tmp]
    end

    def run
      success = convert && make_thumbnails
      success &&= segment if outputs.index { |output| output.type == 'segmented' }
      clear if clear_tmp && success
      success
    end

    private

    def convert
      Ffmpeg.new(inputs, outputs).run
    end

    def make_thumbnails
      if output = outputs.detect { |output| output.thumbnails }
        VideoScreenshoter.new(output.thumbnails.merge(:input => output.ffmpeg_output, :output_dir => File.join(output.work_dir, 'thumbnails'))).run
      else
        true
      end
    end

    def segment
      LiveSegmenter.new(inputs, outputs).run
    end

    def clear
      `cat #{outputs.first.log} >> #{VideoConverter.log} && rm #{outputs.first.log}`
      outputs.map { |output| output.passlogfile }.uniq.compact.each { |passlogfile| `rm #{passlogfile}*` }
      outputs.select { |output| output.type == 'segmented' }.each { |output| `rm #{output.ffmpeg_output}` }
    end
  end
end
