require 'test_helper'

class InputTest < Test::Unit::TestCase
  setup do
    @test_url = 'http://techslides.com/demos/sample-videos/small.mp4'
  end

  context 'exists' do
    context 'when it is local' do
      context 'and exists' do
        should 'return true' do
          assert VideoConverter::Input.new('test/fixtures/test.mp4').exists?
        end
      end

      context 'and does not exist or is not file' do
        should 'return false' do
          assert !VideoConverter::Input.new('test/fixtures/not_existed_file').exists?
          assert !VideoConverter::Input.new('test/fixtures').exists?
        end
      end
    end

    context 'when it is http' do
      context 'and exists' do
        should 'return true' do
          assert VideoConverter::Input.new(@test_url)
        end
      end

      context 'when does not exist or is not file' do
        should 'return false' do
          assert !VideoConverter::Input.new(@test_url + 'any').exists?
          assert !VideoConverter::Input.new(URI.parse(@test_url).host).exists?
        end
      end
    end
  end
          
  context 'metadata' do
    context 'when input does not exist' do
      should 'be empty' do
        assert VideoConverter::Input.new('test/fixtures/not_existed_file').metadata.empty?
      end
    end

    context 'when input is dir' do
      should 'be empty' do
        assert VideoConverter::Input.new('tmp/fixtures').metadata.empty?
      end
    end

    context 'when input is not video file' do
      should 'be empty' do
        assert VideoConverter::Input.new(__FILE__).metadata.empty?
      end
    end

    context 'when input is video file' do
      should 'not be empty' do
        h = {:audio_bitrate_in_kbps=>97, :audio_codec=>"aac", :audio_sample_rate=>44100, :channels=>2, :duration_in_ms=>4019, :total_bitrate_in_kbps=>1123, :frame_rate=>29.97, :height=>360, :video_bitrate_in_kbps=>1020, :video_codec=>"h264", :width=>640, :file_size_in_bytes=>564356, :format=>"mp4"}
        assert_equal h, VideoConverter::Input.new('test/fixtures/test.mp4').metadata
      end
    end

    context 'when input is url' do
      should 'not be empty' do
        h = {:audio_codec=>"aac", :audio_sample_rate=>48000, :audio_bitrate_in_kbps=>83, :channels=>2, :duration_in_ms=>5570, :total_bitrate_in_kbps=>551, :video_codec=>"h264", :width=>560, :height=>320, :video_bitrate_in_kbps=>465, :frame_rate=>30.0, :file_size_in_bytes=>383631, :format=>"mp4"}
        assert_equal h, VideoConverter::Input.new(@test_url).metadata
      end
    end
  end
end
