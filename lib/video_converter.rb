require "video_converter/version"
require "video_converter/ffmpeg"
require "video_converter/profile"
require "video_converter/base"

module VideoConverter
  class << self
    attr_accessor :one_pass, :type, :debug
  end
  
  self.one_pass = false
  self.type = :mp4
  self.debug = false

  def self.run params
    VideoConverter::Base.new(params).run
  end
end
