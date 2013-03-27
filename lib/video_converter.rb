require "video_converter/version"
require "video_converter/ffmpeg"
require "video_converter/profile"
require "video_converter/base"

module VideoConverter
  class << self
    attr_accessor :one_pass, :type, :paral, :debug, :verbose
  end
  
  self.one_pass = false
  self.type = :mp4
  self.paral = true
  self.debug = false
  self.verbose = true

  def self.run params
    VideoConverter::Base.new(params).run
  end
end
