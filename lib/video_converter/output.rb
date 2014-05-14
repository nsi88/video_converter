# encoding: utf-8

module VideoConverter
  class Output
    class << self
      attr_accessor :work_dir, :keyint_min, :keyframe_interval, :keyframe_interval_in_seconds, :threads, :video_codec, :audio_codec
    end

    self.work_dir = '/tmp'
    self.keyint_min = 25
    self.keyframe_interval = 100
    self.keyframe_interval_in_seconds = 4
    self.threads = 1
    self.video_codec = 'libx264'
    self.audio_codec = 'libfaac'

    attr_accessor :uid, :work_dir, :log, :threads, :passlogfile
    attr_accessor :type, :filename
    attr_accessor :format, :ffmpeg_output, :video_codec, :audio_codec, :bitstream_format
    attr_accessor :one_pass, :video_bitrate, :audio_bitrate
    attr_accessor :streams, :path, :chunks_dir
    attr_accessor :frame_rate, :keyint_min, :keyframe_interval, :force_keyframes
    attr_accessor :size, :width, :height, :video_filter
    attr_accessor :thumbnails
    attr_accessor :rotate, :deinterlace
    attr_accessor :faststart

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
        raise ArgumentError.new('Invalid playlist extension') if type == 'playlist' && !['f4m', 'm3u8'].include?(format)
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
      self.frame_rate = params[:frame_rate]
      self.keyint_min = params[:keyint_min] || self.class.keyint_min
      self.keyframe_interval = params[:keyframe_interval] || self.class.keyframe_interval

      # Resolution
      self.size = params[:size]
      self.width = params[:size] ? params[:size].split('x').first : params[:width]
      self.height = params[:size] ? params[:size].split('x').last : params[:height]
      self.size = "#{width}x#{height}" if !size && width && height

      #Thumbnails
      self.thumbnails = params[:thumbnails]

      # Video processing
      self.rotate = params[:rotate]
      unless [nil, true, false].include? rotate
        self.rotate = rotate.to_i
        raise ArgumentError.new('Invalid rotate') unless [0, 90, 180, 270].include? rotate
      end
      self.deinterlace = params[:deinterlace]

      #Faststart
      self.faststart = params.has_key?(:faststart) ? params[:faststart] : self.format == 'mp4'
    end
  end
end
