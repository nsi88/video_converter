# encoding: utf-8

module VideoConverter
  class Output
    class << self
      attr_accessor :work_dir, :keyframe_interval, :threads, :video_codec, :audio_codec
    end

    self.work_dir = '/tmp'
    self.keyframe_interval = 250
    self.threads = 1
    self.video_codec = 'libx264'
    self.audio_codec = 'libfaac'

    attr_accessor :uid, :work_dir, :log, :threads, :passlogfile
    attr_accessor :type, :filename
    attr_accessor :format, :ffmpeg_output, :video_codec, :audio_codec, :bitstream_format
    attr_accessor :one_pass, :video_bitrate, :audio_bitrate
    attr_accessor :streams, :path, :chunks_dir
    attr_accessor :keyframe_interval, :frame_rate
    attr_accessor :size, :width, :height, :video_filter
    attr_accessor :thumbnails
    attr_accessor :rotate

    def initialize params = {}
      # Inner
      self.uid = params[:uid].to_s
      self.work_dir = File.join(self.class.work_dir, uid)
      FileUtils.mkdir_p(work_dir)
      self.log = File.join(work_dir, 'converter.log')
      self.threads = params[:threads] || self.class.threads
      # NOTE passlogile is defined in input

      # General output options
      self.type = params[:type]
      raise ArgumentError.new('Incorrect type') if type && !%w(default segmented playlist).include?(type)
      self.filename = params[:filename] or raise ArgumentError.new('filename required')

      # Formats and codecs
      if type == 'segmented'
        self.format = 'mpegts'
        self.ffmpeg_output = File.join(work_dir, File.basename(filename, '.*') + '.ts')
      else
        self.format = File.extname(filename).sub('.', '')
        self.ffmpeg_output = File.join(work_dir, filename)
      end
      self.video_codec = params[:video_codec] || self.class.video_codec
      self.audio_codec = params[:audio_codec] || self.class.audio_codec
      self.bitstream_format = params[:bitstream_format]

      # Rate controle
      self.one_pass = !!params[:one_pass]
      self.video_bitrate = "#{params[:video_bitrate]}k" if params[:video_bitrate]
      self.audio_bitrate = "#{params[:audio_bitrate]}k" if params[:audio_bitrate]

      # Segmented streaming
      self.streams = params[:streams]
      self.path = params[:path]
      if type == 'segmented'
        self.chunks_dir = File.join(work_dir, File.basename(filename, '.*'))
        FileUtils.mkdir_p(chunks_dir)
      end

      # Frame rate
      self.keyframe_interval = params[:keyframe_interval] || self.class.keyframe_interval
      self.frame_rate = params[:frame_rate]

      # Resolution
      self.size = params[:size]
      self.width = params[:width]
      self.height = params[:height]

      #Thumbnails
      self.thumbnails = params[:thumbnails]

      # Video processing
      self.rotate = params[:rotate]
      unless [nil, true, false].include? rotate
        self.rotate = rotate.to_i
        raise ArgumentError.new('Invalid rotate') unless [0, 90, 180, 270].include? rotate
      end
    end
  end
end
