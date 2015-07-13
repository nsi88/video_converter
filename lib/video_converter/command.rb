# encoding: utf-8

module VideoConverter
  class Command
    class << self
      attr_accessor :dry_run, :verbose, :nice, :ionice
    end
    self.dry_run = false
    self.verbose = true

    attr_accessor :command

    def initialize command, params = {}, safe_keys = []
      self.command = command.dup
      if params.any?
        params = params.deep_shellescape_values(safe_keys)
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
      self.command = "nice -n #{self.class.nice} #{self.command}" if self.class.nice
      self.command = "ionice -c 2 -n #{self.class.ionice} #{self.command}" if self.class.ionice
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
    
    def append(*commands)
      self.command = commands.unshift(command).map { |c| "(#{c})" }.join(' && ')
      self
    end
  end
end
