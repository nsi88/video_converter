require "video_converter/version"
require "video_converter/base"
require "video_converter/command"
require "video_converter/process"
require "video_converter/ffmpeg"
require "video_converter/live_segmenter"
require "video_converter/input"
require "video_converter/output"
require "video_converter/output_array"
require "fileutils"
require "net/http"

module VideoConverter
  class << self
    attr_accessor :paral
  end
  
  self.paral = true

  def self.new params
    VideoConverter::Base.new params
  end

  def self.find id
    VideoConverter::Process.new id
  end
end
