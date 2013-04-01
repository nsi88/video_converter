require "video_converter/version"
require "video_converter/profile"
require "video_converter/base"
require "video_converter/command"
require "video_converter/process"
require "video_converter/ffmpeg"
require "video_converter/live_segmenter"
require "fileutils"

module VideoConverter
  class << self
    attr_accessor :type, :paral, :no_convert
  end
  
  self.type = :mp4
  self.paral = true
  self.no_convert = false

  def self.new params
    VideoConverter::Base.new params
  end

  def self.find id
    VideoConverter::Process.new id
  end
end
