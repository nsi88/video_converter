# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input, :profile, :one_pass, :type, :paral, :log, :id, :playlist_dir, :chunk_base, :no_convert

    def initialize params
      self.no_convert = params[:no_convert].nil? ? VideoConverter.no_convert : params[:no_convert]
      unless no_convert
        self.input = params[:input] or raise ArgumentError.new('Input is needed')
        raise ArgumentError.new('Input does not exist') unless File.exists?(input)
      end
      self.profile = params[:profile] or raise ArgumentError.new('Profile is needed')
      self.type = params[:type].nil? ? VideoConverter.type : params[:type].to_sym
      raise ArgumentError.new("Incorrect type #{type}") unless [:hls, :mp4].include?(type)
      if type == :hls
        self.playlist_dir = params[:playlist_dir] or raise ArgumentError.new("Playlist dir is needed")
      end
      self.one_pass = params[:one_pass].nil? ? Ffmpeg.one_pass : params[:one_pass]
      self.paral = params[:paral].nil? ? VideoConverter.paral : params[:paral]
      if params[:log].nil?
        self.log = '/dev/null'
      else
        self.log = params[:log]
        FileUtils.mkdir_p File.dirname(log)
      end
      self.id = object_id
      self.chunk_base = params[:chunk_base]
    end

    def run
      process = VideoConverter::Process.new(id)
      process.pid = `cat /proc/self/stat`.split[3]
      actions = []
      actions << :convert unless no_convert
      actions << :live_segment if type == :hls
      actions.each do |action|
        process.status = action.to_s
        process.progress = 0
        res = send action
        if res
          process.status = "#{action}_success"
        else
          process.status = "#{action}_error"
          return false
        end
      end
      true
    end

    private

    def convert
      params = {}
      [:input, :profile, :one_pass, :paral, :log].each do |param|
        params[param] = self.send(param)
      end
      Ffmpeg.new(params).run
    end

    def live_segment
      params = {}
      [:profile, :playlist_dir, :paral, :chunk_base, :log, :no_convert].each do |param|
        params[param] = self.send(param)
      end
      params[:delete_input] = false if no_convert
      LiveSegmenter.new(params).run
    end
  end
end
