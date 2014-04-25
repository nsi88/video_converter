# encoding: utf-8

module VideoConverter
  class Hds
  	class << self
      attr_accessor :bin, :command
    end
    self.bin = '/usr/local/bin/mp4frag'
    self.command = '%{bin} %{inputs} --manifest %{manifest} --index 1>>%{log} 2>&1 || exit 1'

    attr_accessor :input, :group

    def initialize input, group
      self.input = input
      self.group = group
    end

    def run
      success = true
      threads = []
			command = Command.new(self.class.command, prepare_params(group))
      if VideoConverter.paral
        threads << Thread.new { success &&= command.execute }
      else
        success &&= command.execute
      end
      threads.each { |t| t.join } if VideoConverter.paral
      success
		end

		private

		def prepare_params(group)
			{
				:bin => self.class.bin,
				:inputs => group.select { |output| output.type != 'playlist' }.map { |input| "--src #{input.ffmpeg_output}" }.join(' '),
				:manifest => group.detect { |output| output.type == 'playlist' }.ffmpeg_output,
				:log => group.first.log
			}
		end
	end
end