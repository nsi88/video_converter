# encoding: utf-8

module VideoConverter
  class Output
    class << self
      attr_accessor :work_dir, :log, :keyframe_interval_in_seconds
    end
    self.work_dir = '/tmp'
    self.log = 'converter.log'
    self.keyframe_interval_in_seconds = 4

    attr_accessor :chunks_dir, :crop, :drm, :faststart, :ffmpeg_output, :filename, :group, :height, :log, :mkdir_mode, :no_fragments, :one_pass, :options, :path, :rotate, :streams, :thumbnails, :type, :uid, :volume, :watermarks, :width, :work_dir

    def initialize params = {}
      self.work_dir = File.join(self.class.work_dir, params[:uid])
      self.mkdir_mode = params[:mkdir_mode]
      self.mkdir_mode = mkdir_mode.to_i(8) if mkdir_mode.is_a?(String)
      FileUtils.mkdir_p(work_dir, :mode => mkdir_mode)
      self.filename = params[:filename] or raise ArgumentError.new('Filename required')
      self.log = File.join(work_dir, self.class.log)
      self.type = params[:type] || 'default'
      if type == 'segmented'
        self.chunks_dir = File.join(work_dir, File.basename(filename, '.*'))
        FileUtils.mkdir_p(chunks_dir, :mode => mkdir_mode)
        if File.extname(filename) == '.m3u8'
          self.ffmpeg_output = chunks_dir + '.ts'
          params[:format] = 'mpegts'
        elsif File.extname(filename) == '.f4m'
          self.ffmpeg_output = chunks_dir = '.mp4'
          params[:format] = 'mp4'
        else
          raise "Invalid filename for type segmented"
        end
      else
        self.ffmpeg_output = File.join(work_dir, filename)
      end
      raise ArgumentError.new('Invalid type') unless %w(default segmented playlist).include?(type)
      [:path, :streams, :width, :height, :one_pass, :rotate, :faststart, :thumbnails, :group, :drm, :no_fragments, :crop, :watermarks, :volume].each { |attr| self.send("#{attr}=", params[attr]) }
      [:video_bitrate, :audio_bitrate].each { |bitrate| params[bitrate] = "#{params[bitrate]}k" if params[bitrate].is_a?(Numeric) }

      # options will be substituted to convertation commands
      self.options = params
    end

    def output_group(outputs)
      paths = streams.map { |stream| stream[:path] }
      outputs.select { |output| paths.include?(output.filename) }.unshift(self)
    end
  end
end
