# encoding: utf-8

module VideoConverter
  class Command
    class << self
      attr_accessor :dry_run, :verbose
    end
    self.dry_run = false
    self.verbose = true

    def self.chain(*commands)
      commands.map { |c| "(#{c})" }.join(' && ')
    end

    attr_accessor :command

    def initialize command, *params
      self.command = command.dup
      if params.any?
        if params[0].is_a?(Hash)
          self.command.gsub!(/%\{(\w+?)\}/) { |m| params[0][$1.to_sym] }
        else
          self.command.gsub!('?') { params.shift }
        end
      end
      raise ArgumentError.new("Command is not parsed '#{self.command}'") if self.command.include?('?') || self.command.match(/%{[\w\-.]+}/)
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
