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
      success = convert && faststart && make_screenshots && segment
      clear if clear_tmp && success
      success
    end

    def convert
      success = true
      inputs.each do |input|
        input.output_groups.each do |group|
          success &&= Ffmpeg.new(input, group).run
        end
      end
      success
    end

    def faststart
      success = true
      outputs.each do |output|
        success &&= Faststart.new(output).run if output.faststart
      end
      success
    end

    def make_screenshots
      success = true
      outputs.each do |output|
        success &&= VideoScreenshoter.new(output.thumbnails.merge(:input => output.ffmpeg_output, :output_dir => File.join(output.work_dir, 'thumbnails'))).run if output.thumbnails
      end
      success
    end

    def segment
      success = true
      inputs.each do |input|
        input.output_groups.each do |group|
          if playlist = group.detect { |output| output.type == 'playlist' }
            success &&= if playlist.format == 'm3u8'
              LiveSegmenter.new(input, group).run
            else
              Hds.new(input, group).run
            end
          end
        end
      end
    end

    def split
      Ffmpeg.new(inputs.first, outputs).split
    end

    def concat
      list = File.join(outputs.first.work_dir, 'list.txt')
      # NOTE ffmpeg concat list requires unescaped files
      File.write(list, inputs.map { |input| "file '#{File.absolute_path(input.unescape)}'" }.join("\n"))
      success = Ffmpeg.new(list, outputs).concat
      FileUtils.rm list if success
      success
    end

    def mux
      Ffmpeg.new(inputs, outputs).mux
    end

    def clear
      `cat #{outputs.first.log} >> #{VideoConverter.log} && rm #{outputs.first.log}`
      outputs.map { |output| output.passlogfile }.uniq.compact.each { |passlogfile| `rm #{passlogfile}*` }
      outputs.select { |output| output.type == 'segmented' }.each { |output| `rm #{output.ffmpeg_output}` }
    end
  end
end
