# encoding: utf-8

module VideoConverter
  class Ffmpeg
    class << self
      attr_accessor :bin, :one_pass, :one_pass_command, :first_pass_command, :second_pass_command
    end

    self.bin = '/usr/local/bin/ffmpeg'

    self.one_pass = false
    
    self.one_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -b:v %{bitrate}k -bt %{bitrate}k -threads %{threads} -f mp4 %{file} 1>%{log} 2>&1 || exit 1"

    self.first_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -an -vcodec libx264 -g 100 -keyint_min 50 -pass 1 -passlogfile %{input}.log -b:v 700k -bt 700k -threads %{threads} -f mp4 /dev/null  1>>%{log} 2>&1 || exit 1"

    self.second_pass_command = "%{bin} -i %{input} -y -aspect %{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -pass 2 -passlogfile %{input}.log -b:v %{bitrate}k -bt %{bitrate}k -threads %{threads} -f mp4 %{file} 1>%{log} 2>&1 || exit 1"

    attr_accessor :input, :profile, :one_pass, :paral, :log

    def initialize params
      params.each do |param, value|
        self.send("#{param}=", value)
      end
    end

    def run
      res = true
      threads = []
      Profile.groups(profile).each do |qualities|
        unless one_pass
          group_command = Command.new self.class.first_pass_command, common_params.merge(qualities.first.to_hash)
          res &&= group_command.execute
        end
        qualities.each do |quality|
          if one_pass
            quality_command = Command.new self.class.one_pass_command, common_params.merge(quality.to_hash)
          else
            quality_command = Command.new self.class.second_pass_command, common_params.merge(quality.to_hash)
          end
          if paral
            threads << Thread.new { res &&= quality_command.execute }
          else
            res &&= quality_command.execute
          end
        end
      end
      threads.each { |t| t.join } if paral
      res
    end

    private 

    def common_params
      { :bin => self.class.bin, :input => input, :log => log }
    end
  end
end
