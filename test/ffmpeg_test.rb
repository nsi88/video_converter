require 'test_helper'

class FfmpegTest < Test::Unit::TestCase
  context 'metadata' do
    context 'when input does not exist' do
      should 'be empty' do
        assert VideoConverter::Ffmpeg.new(:input => 'tmp/fixtures/not_existed_file').metadata.empty?
      end
    end

    context 'when input is dir' do
      should 'be empty' do
        assert VideoConverter::Ffmpeg.new(:input => 'tmp/fixtures').metadata.empty?
      end
    end

    context 'when input is not video file' do
      should 'be empty' do
        assert VideoConverter::Ffmpeg.new(:input => __FILE__).metadata.empty?
      end
    end

    context 'when input is video file' do
      should 'not be empty' do
        h = {:audio_bitrate_in_kbps=>97, :audio_codec=>"aac", :audio_sample_rate=>44100, :channels=>2, :duration_in_ms=>4019, :total_bitrate_in_kbps=>1123, :frame_rate=>29.97, :height=>360, :video_bitrate_in_kbps=>1020, :video_codec=>"h264", :width=>640, :file_size_in_bytes=>564356, :format=>"mp4"}
        assert_equal h, VideoConverter::Ffmpeg.new(:input => 'test/fixtures/test.mp4').metadata
      end
    end
  end
end
