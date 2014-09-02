# encoding: utf-8

module VideoConverter
  class Mp4frag
  	class << self
      attr_accessor :bin, :command
    end
    self.bin = '/usr/local/bin/mp4frag'
    self.command = 'bash -c "pushd %{work_dir}; %{bin} %{inputs} --manifest %{manifest} --index 1>>%{log} 2>&1 || exit 1; popd"'

    def self.run(outputs)
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
        :work_dir =>  outputs.select { |output| output.type != 'playlist' }.first.work_dir,
				:bin => bin,
				:inputs => outputs.select { |output| output.type != 'playlist' }.map { |input| "--src #{File.basename(input.ffmpeg_output)}" }.join(' '),
				:manifest => outputs.detect { |output| output.type == 'playlist' }.ffmpeg_output,
				:log => outputs.first.log
			}
		end
	end
end
