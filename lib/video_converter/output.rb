# encoding: utf-8

module VideoConverter
  class Output
    class << self
      attr_accessor :base_url, :work_dir, :video_bitrate, :segment_seconds
    end

    self.base_url = '/tmp'
    self.work_dir = '/tmp'
    self.video_bitrate = 700
    self.segment_seconds = 10

    attr_accessor :type, :url, :base_url, :filename, :format, :video_bitrate, :uid, :streams, :work_dir, :local_path, :playlist, :items, :segment_seconds, :chunks_dir

    def initialize params = {}
      self.uid = params[:uid].to_s.empty? ? Socket.gethostname + self.object_id.to_s : params[:uid].to_s

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
      self.work_dir = params[:work_dir] || self.class.work_dir
      format_regexp = Regexp.new("#{File.extname(filename)}$")
      self.local_path = File.join(work_dir, filename.sub(format_regexp, ".#{format}"))
      if type == :segmented
        self.chunks_dir = File.join(work_dir, filename.sub(format_regexp, ''))
        FileUtils.mkdir_p chunks_dir
      end

      # Rate controle
      self.video_bitrate = params[:video_bitrate].to_i > 0 ? params[:video_bitrate].to_i : self.class.video_bitrate

      # Segmented streaming
      self.streams = params[:streams].to_a
      self.segment_seconds = params[:segment_seconds] || self.class.segment_seconds
    end

    def to_hash
      keys = [:video_bitrate, :local_path, :segment_seconds, :chunks_dir]
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
      stream_paths = streams.map { |stream| stream['path'] }
      self.class.outputs(output).select { |output| stream_paths.include? output.filename }
    end
  end
end
