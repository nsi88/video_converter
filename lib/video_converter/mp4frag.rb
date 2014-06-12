# encoding: utf-8

module VideoConverter
  class Mp4frag
  	class << self
      attr_accessor :bin, :command
    end
    self.bin = '/usr/local/bin/mp4frag'
    self.command = '%{bin} %{inputs} --manifest %{manifest} --index 1>>%{log} 2>&1 || exit 1'

    def self.run(input, outputs)
      success = true
      threads = []
			command = Command.new(self.command, prepare_params(outputs))
      if VideoConverter.paral
        threads << Thread.new { success &&= command.execute }
      else
        success &&= command.execute
      end
      threads.each { |t| t.join } if VideoConverter.paral
      success
		end

		private

		def self.prepare_params(outputs)
			{
				:bin => bin,
				:inputs => outputs.select { |output| output.type != 'playlist' }.map { |input| "--src #{input.ffmpeg_output}" }.join(' '),
				:manifest => outputs.detect { |output| output.type == 'playlist' }.ffmpeg_output,
				:log => outputs.first.log
			}
		end
	end
end