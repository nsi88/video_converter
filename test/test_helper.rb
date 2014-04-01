$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'test/unit'
require 'shoulda-context'
require 'video_converter'

VideoConverter::Command.verbose = true
VideoConverter::Output.work_dir = 'tmp'