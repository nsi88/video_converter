# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :bin, :one_pass_command, :first_pass_command, :second_pass_command
    end

    self.bin = '/usr/local/bin/ffmpeg'
    
    self.one_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -b:v %{bitrate}k -bt %{bitrate}k -threads %{threads} -f mp4 %{output} || exit 1"

    self.first_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -an -vcodec libx264 -g 100 -keyint_min 50 -pass 1 -passlogfile %{input}.log -b:v 700k -bt 700k -threads %{threads} -f mp4 /dev/null || exit 1"

    self.second_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -pass 2 -passlogfile %{input}.log -b:v %{bitrate}k -bt %{bitrate}k -threads %{threads} -f mp4 %{output} || exit 1"
  end
end
