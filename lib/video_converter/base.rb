# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :inputs, :outputs

    def initialize params
      self.inputs = Array.wrap(params[:input] || params[:inputs]).map { |input|  Input.new(input) }
      self.outputs = Array.wrap(params[:output] || params[:outputs]).map { |output| Output.new(output.merge(:uid => params[:uid] ? params[:uid].to_s : (Socket.gethostname + object_id.to_s))) }
    end

    def run
      convert && make_screenshots && segment && encrypt && clear
    end

    # XXX inject instead of each would be better
    def convert
      success = true
      inputs.each { |input| success &&= Ffmpeg.new(input, outputs).run }
      success
    end

    def make_screenshots
      success = true
      outputs.each do |output|
        success &&= VideoScreenshoter.new(output.thumbnails.merge(:ffmpeg => Ffmpeg.bin, :input => output.ffmpeg_output, :output_dir => File.join(output.work_dir, 'thumbnails'))).run if output.thumbnails
      end
      success
    end

    def segment
      success = true
      outputs.select { |output| output.type == 'playlist' }.each do |playlist|
        paths = playlist.streams.map { |stream| stream[:path] }
        group = outputs.select { |output| paths.include?(output.filename) }.unshift(playlist)
        success &&= (playlist.filename.end_with?('m3u8') ? LiveSegmenter : Mp4frag).send(:run, group)
      end
      success
    end

    def encrypt(options = {})
      outputs.each do |output|
        case output.drm
        when 'adobe'
          output.options.merge!(options)
          F4fpackager.run(output) or return false
        when 'hls'
          output.options.merge!(options)
          OpenSSL.run(output) or return false
        end
      end
      true
    end

    def clear
      Command.new("cat #{outputs.first.log} >> #{VideoConverter.log} && rm #{outputs.first.log}").execute
      outputs.map { |output| output.options[:passlogfile] }.uniq.compact.each { |passlogfile| Command.new("rm #{passlogfile}*").execute }
      outputs.select { |output| output.type == 'segmented' }.each { |output| Command.new("rm #{output.ffmpeg_output}").execute }
      true
    end

    def split
      Ffmpeg.split(inputs.first, outputs.first)
    end

    def concat method = nil
      Ffmpeg.concat(inputs, outputs.first, method)
    end

    def mux
      Ffmpeg.mux(inputs, outputs.first)
    end
  end
end
