require 'test_helper'

class HlsTest < Test::Unit::TestCase
	setup do
		@concat = "/tmp/test_concat.mp4"
		VideoConverter::Hls.new({:input=>"test/fixtures/test_playlist.m3u8", :output=>@concat}).concat
	end

	should 'concat' do
		metadata = VideoConverter.new(:input => @concat).inputs.first.metadata
		assert metadata[:duration_in_ms] > 20_000
		assert_equal 'mp4', metadata[:format]
	end
end