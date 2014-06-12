# encoding: utf-8

module VideoConverter
  class Output
    class << self
      attr_accessor :work_dir, :log, :keyframe_interval_in_seconds
    end
    self.work_dir = '/tmp'
    self.log = 'converter.log'
    self.keyframe_interval_in_seconds = 4

    attr_accessor :work_dir, :filename, :log, :type, :chunks_dir, :ffmpeg_output, :path, :streams, :width, :height, :one_pass, :rotate, :faststart, :thumbnails, :options

    def initialize params = {}
      self.work_dir = File.join(self.class.work_dir, params.delete(:uid))
      FileUtils.mkdir_p(work_dir)
      self.filename = params.delete(:filename) or raise ArgumentError.new('Filename required')
      self.log = File.join(work_dir, self.class.log)
      self.type = params.delete(:type) || 'default'
      if type == 'segmented'
        self.chunks_dir = File.join(work_dir, File.basename(filename, '.*'))
        FileUtils.mkdir_p(chunks_dir)
        self.ffmpeg_output = chunks_dir + '.ts'
        params[:format] = 'mpegts'
      else
        self.ffmpeg_output = File.join(work_dir, filename)
      end
      raise ArgumentError.new('Invalid type') unless %w(default segmented playlist).include?(type)
      [:path, :streams, :width, :height, :one_pass, :rotate, :faststart, :thumbnails].each { |attr| self.send("#{attr}=", params.delete(attr)) }
      [:video_bitrate, :audio_bitrate].each { |bitrate| params[bitrate] = "#{params[bitrate]}k" if params[bitrate].is_a?(Numeric) }

      # options will be substituted to convertation commands
      self.options = params
    end
  end
end
