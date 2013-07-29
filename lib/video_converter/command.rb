# encoding: utf-8

module VideoConverter
  class Command
    class << self
      attr_accessor :debug, :verbose
    end
    self.debug = false
    self.verbose = false

    attr_accessor :command

    def initialize command, params = {}
      res = command.clone
      params.each do |param, value|
        res.gsub! "%{#{param}}", value.to_s.empty? ? '' : Shellwords.escape(value.to_s)
      end
      self.command = res
      raise ArgumentError.new("Command is not parsed '#{self.command}'") if self.command.match(/%{[\w\-.]+}/)
    end

    def execute params = {}
      puts command if params[:verbose] || self.class.verbose
      if params[:debug] || self.class.debug
        true
      else
        system command
      end
    end

    def to_s
      command
    end
  end
end
