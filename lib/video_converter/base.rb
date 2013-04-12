# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input_array, :output_array, :log, :uid

    def initialize params
      self.input_array = InputArray.new(params[:input])
      input_array.inputs.each { |input| raise ArgumentError.new("#{input} does not exist") unless input.exists? }
      self.uid = params[:uid] || (Socket.gethostname + object_id.to_s)
      self.output_array = OutputArray.new(params[:output] || {}, uid)
      if params[:log].nil?
        self.log = '/dev/null'
      else
        self.log = params[:log]
        FileUtils.mkdir_p File.dirname(log)
      end
    end

    def run
      process = VideoConverter::Process.new(uid)
      process.status = 'started'
      process.pid = `cat /proc/self/stat`.split[3]
      actions = []
      actions = [:convert, :segment]
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
      process.status = 'finished'
      true
    end

    private

    def convert
      params = {}
      [:input_array, :output_array, :log].each do |param|
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
  end
end
