# encoding: utf-8

module VideoConverter
  class Faststart
    class << self
      attr_accessor :bin, :command
    end
    self.bin = '/usr/local/bin/qt-faststart'
    self.command = '%{bin} %{input} %{moov_atom} && mv %{moov_atom} %{input} 1>>%{log} 2>&1 || exit 1'

    attr_accessor :output

    def initialize output
      self.output = output
    end

    def run
      success = true
      success &&= Command.new(self.class.command, prepare_params(output)).execute
      success
    end

    private

    def prepare_params(output)
      {
        :bin => self.class.bin,
        :log => output.log,
        :input => output.ffmpeg_output,
        :moov_atom => "#{output.ffmpeg_output}.mov"
      }
    end

  end
end
