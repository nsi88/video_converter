require "fileutils"
require "net/http"
require "shellwords"
require "video_converter/array"
require "video_converter/base"
require "video_converter/command"
require "video_converter/faststart"
require "video_converter/ffmpeg"
require "video_converter/hash"
require "video_converter/hls"
require "video_converter/input"
require "video_converter/live_segmenter"
require "video_converter/mp4frag"
require "video_converter/object"
require "video_converter/output"
require "video_converter/version"
require "video_screenshoter"

module VideoConverter
  class << self
    attr_accessor :log, :paral
  end
  # TODO log into tmp log file, merge to main log, delete tmp log
  self.log = 'log/converter.log'
  # TODO output option
  self.paral = true

  def self.new params
    VideoConverter::Base.new params.deep_symbolize_keys.deep_shellescape_values
  end
end
