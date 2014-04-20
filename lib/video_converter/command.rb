# encoding: utf-8

module VideoConverter
  class Command
    class << self
      attr_accessor :dry_run, :verbose
    end
    self.dry_run = false
    self.verbose = false

    attr_accessor :command

    def initialize command, params = {}
      self.command = command.gsub(/%\{(\w+?)\}/) { |m| params[$1.to_sym] }
      raise ArgumentError.new("Command is not parsed '#{self.command}'") if self.command.match(/%{[\w\-.]+}/)
    end

    def execute params = {}
      puts command if params[:verbose] || self.class.verbose
      if params[:dry_run] || self.class.dry_run
        true
      else
        system command
      end
    end

    def capture params = {}
      puts command if params[:verbose] || self.class.verbose
      `#{command}`.encode!('UTF-8', 'UTF-8', :invalid => :replace)
    end

    def to_s
      command
    end
  end
end
