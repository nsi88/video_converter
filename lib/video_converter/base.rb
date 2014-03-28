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
      FileUtils.mkdir_p(File.dirname(VideoConverter.log))
    end

    def run
      success = true
      [:convert, :segment, :screenshot].each { |action| success &&= send(action) }
      clear if clear_tmp && success
      success
    end

    private

    def convert
      Ffmpeg.new(inputs, outputs).run
    end

    def segment
      LiveSegmenter.new(inputs, outputs).run
    end

    def screenshot
      # TODO use VideoScreenshoter
      true
    end

    def clear
      # TODO delete logs and ts file for segmented type if clear_tmp is true
    end
  end
end
