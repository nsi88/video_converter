# encoding: utf-8

module VideoConverter
  class Output
    class << self
      attr_accessor :base_url, :work_dir, :video_bitrate, :audio_bitrate, :segment_seconds, :keyframe_interval, :threads, :video_codec, :audio_codec
    end

    self.base_url = '/tmp'
    self.work_dir = '/tmp'
    self.video_bitrate = 700
    self.audio_bitrate = 200
    self.segment_seconds = 10
    self.keyframe_interval = 250
    self.threads = 1
    self.video_codec = 'libx264'
    self.audio_codec = 'libfaac'

    attr_accessor :type, :url, :base_url, :filename, :format, :video_bitrate, :uid, :streams, :work_dir, :local_path, :playlist, :items, :segment_seconds, :chunks_dir, :audio_bitrate, :keyframe_interval, :threads, :video_codec, :audio_codec, :path

    def initialize params = {}
      self.uid = params[:uid].to_s

      # General output options
      self.type = params[:type] ? params[:type].to_sym : :standard
      raise ArgumentError.new('Incorrect type') unless %w(standard segmented playlist transfer-only).include?(type.to_s)

      self.format = params[:format]
      if !format && params[:filename]
        self.format = File.extname(params[:filename]).sub('.', '')
      end
      if format == 'm3u8' || !format && type == :segmented
        self.format = 'ts'
      end
      self.format = 'mp4' if format.nil? || format.empty?
      raise ArgumentError.new('Incorrect format') unless %w(3g2 3gp 3gp2 3gpp 3gpp2 aac ac3 eac3 ec3 f4a f4b f4v flv highwinds m4a m4b m4r m4v mkv mov mp3 mp4 oga ogg ogv ogx ts webm wma wmv).include?(format)
      
      self.base_url = (params[:url] ? File.dirname(params[:url]) : params[:base_url]) || self.class.base_url
      self.filename = (params[:url] ? File.basename(params[:url]) : params[:filename]) || self.uid + '.' + self.format
      self.url = params[:url] ? params[:url] : File.join(base_url, filename)
      self.work_dir = File.join(params[:work_dir] || self.class.work_dir, uid)
      format_regexp = Regexp.new("#{File.extname(filename)}$")
      self.local_path = File.join(work_dir, filename.sub(format_regexp, ".#{format}"))
      FileUtils.mkdir_p File.dirname(local_path)
      if type == :segmented
        self.chunks_dir = File.join(work_dir, filename.sub(format_regexp, ''))
        FileUtils.mkdir_p chunks_dir
      end
      self.threads = self.class.threads
      self.path = params[:path]

      # Rate controle
      self.video_bitrate = params[:video_bitrate].to_i > 0 ? params[:video_bitrate].to_i : self.class.video_bitrate
      self.audio_bitrate = params[:audio_bitrate].to_i > 0 ? params[:audio_bitrate].to_i : self.class.audio_bitrate

      # Segmented streaming
      self.streams = params[:streams].to_a
      self.segment_seconds = params[:segment_seconds] || self.class.segment_seconds

      # Frame rate
      self.keyframe_interval = params[:keyframe_interval].to_i > 0 ? params[:keyframe_interval].to_i : self.class.keyframe_interval

      # Format and codecs
      self.video_codec = (params[:copy_video] ? 'copy' : params[:video_codec]) || self.class.video_codec
      self.audio_codec = (params[:copy_audio] ? 'copy' : params[:audio_codec]) || self.class.audio_codec
    end

    def to_hash
      keys = [:video_bitrate, :local_path, :segment_seconds, :chunks_dir, :audio_bitrate, :keyframe_interval, :threads, :video_codec, :audio_codec]
      Hash[*keys.map{ |key| [key, self.send(key)] }.flatten]
    end

    def self.outputs output
      (output.is_a?(Hash) ? [output] : output).map { |output| output.is_a?(self.class) ? output : new(output) }
    end

    def self.playlists output
      outputs(output).select { |output| output.type == :playlist }
    end

    def qualities output
      raise TypeError.new('Only for playlists') unless type == :playlist
      stream_paths = streams.map { |stream| stream[:path] }
      self.class.outputs(output).select { |output| stream_paths.include? output.filename }
    end
  end
end
