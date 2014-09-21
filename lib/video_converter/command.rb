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

    def initialize command, params = {}, safe_params = []
      self.command = command.dup
      if params.any?
        safe_params = Hash[*safe_params.map { |param| [param, params.delete(param)] }.flatten]
        params = params.deep_shellescape_values.merge(safe_params)
        self.command.gsub!(/%\{(\w+?)\}/) do
          value = params[$1.to_sym]
          if value.is_a?(Hash)
            value.deep_join(' ')
          else
            value.to_s
          end
        end
      end
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
      `#{command}`.encode('UTF-8', 'binary', :invalid => :replace, :undef => :replace, :replace => '')
    end

    def to_s
      command
    end
  end
end
