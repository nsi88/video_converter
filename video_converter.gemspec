# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'video_converter/version'

Gem::Specification.new do |spec|
  spec.name          = "video_converter"
  spec.version       = VideoConverter::VERSION
  spec.authors       = ["novikov"]
  spec.email         = ["novikov@inventos.ru"]
  spec.description   = %q{This gem allows you to convert video files using ffmpeg, mencoder and other user defined utilities to mp4, m3u8, and any other formats}
  spec.summary       = %q{Ffmpeg, mencoder based converter to mp4, m3u8}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
