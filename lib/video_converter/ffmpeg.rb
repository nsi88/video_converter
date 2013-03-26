# encoding: utf-8

class VideoConverter::Ffmpeg
  attr_accessor :bin, :one_pass, :input, :aspect, :bitrate, :threads, :profile

  def initialize opts = {}
    self.bin = opts[:bin] || 'ffmpeg'
    self.one_pass = opts[:one_pass] || false
    self.threads = opts[:threads] || 1
    self.aspect = opts[:aspect] || '4:3'
    oblig_opts.each do |opt|
      self.send "#{opt}=", opts[opt] or raise ArgumentError.new("#{opt} is not passed")
    end
    raise ArgumentError.new('Input file does not exist') unless File.exists?(input)
  end
  
  def one_pass_command output
    "#{bin} -i #{input} -y -aspect #{aspect} -acodec copy -vcodec libx264 -g 100 -keyint_min 50 -b #{bitrate}k -bt #{bitrate}k -threads #{threads} -f mp4 #{output}.mp4 || exit 1"
  end

  def first_pass_command output = nil
    "#{bin} -i #{input} -y -aspect #{aspect} -an -vcodec libx264 -vpre medium_firstpass -g 100 -keyint_min 50 -pass 1 -passlogfile #{input}.log -b 700k -bt 700k -threads #{threads} -f mp4 /dev/null || exit 1"
  end

  def second_pass_command output
    "#{bin} -i #{input} -y -aspect #{aspect} -acodec copy -vcodec libx264 -vpre medium -g 100 -keyint_min 50 -pass 2 -passlogfile #{input}.log -b #{bitrate}k -bt #{bitrate}k -threads #{threads} -f mp4 #{output}.mp4 || exit 1"
  end

  def run
    if one_pass
      execute one_pass_command
    else
      raise NotImplementedError
    end
  end

  private

  def execute cmd
    `#{cmd}`
  end

  def oblig_opts
    [
      :input, :bitrate, :profile
    ]
  end
end
