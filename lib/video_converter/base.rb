# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input, :output_array, :log, :id

    def initialize params
      raise ArgumentError.new('input is needed') if params[:input].nil? || params[:input].empty?
      self.input = Input.new(params[:input])
      raise ArgumentError.new('input does not exist') unless input.exists?
      raise ArgumentError.new('output is needed') if params[:output].nil? || params[:output].empty?
      self.output_array = OutputArray.new(params[:output])
      if params[:log].nil?
        self.log = '/dev/null'
      else
        self.log = params[:log]
        FileUtils.mkdir_p File.dirname(log)
      end
      self.id = Socket.gethostname + object_id.to_s
    end

    def run
      process = VideoConverter::Process.new(id)
      process.pid = `cat /proc/self/stat`.split[3]
      actions = []
      actions = [:copy, :convert, :segment, :deploy]
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

    def copy
      if input.is_local?
        true
      else
        raise NotImplementerError
      end
    end

    def convert
      params = {}
      [:input, :output_array, :log].each do |param|
        params[param] = self.send(param)
      end
      Ffmpeg.new(params).run
    end

    def segment
      params = {}
      [:output_array, :log].each do |param|
        params[param] = self.send(param)
      end
      LiveSegmenter.new(params).run
    end

    def deploy
      true
    end
  end
end
