require "video_converter/version"
require "video_converter/base"
require "video_converter/command"
require "video_converter/process"
require "video_converter/ffmpeg"
require "video_converter/live_segmenter"
require "video_converter/input"
require "video_converter/input_array"
require "video_converter/output"
require "video_converter/output_array"
require "video_converter/hls"
require "fileutils"
require "net/http"
require "video_screenshoter"
require "shellwords"

module VideoConverter
  class << self
    attr_accessor :paral
  end
  
  self.paral = true

  def self.new params
    VideoConverter::Base.new params.deep_symbolize_keys
  end

  def self.find uid
    VideoConverter::Process.new uid
  end
end

Hash.class_eval do
  def deep_symbolize_keys
    inject({}) do |options, (key, value)|
      value = value.map { |v| v.is_a?(Hash) ? v.deep_symbolize_keys : v } if value.is_a? Array
      value = value.deep_symbolize_keys if value.is_a? Hash
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  def deep_symbolize_keys!
    self.replace(self.deep_symbolize_keys)
  end
end
