require 'test_helper'

class VideoConverterTest < Test::Unit::TestCase
  context 'run' do
    setup do
      @input = 'test/fixtures/test.mp4'
    end

    context 'with default type' do
      setup do
        @c = VideoConverter.new(:input => @input, :output => [{:video_bitrate => 300, :filename => 'tmp/test1.mp4'}, {:video_bitrate => 700, :filename => 'tmp/test2.mp4'}], :log => 'tmp/test.log')
        @res = @c.run
      end
      should 'convert files' do
        2.times do |n|
          file = File.join(VideoConverter::Output.work_dir, @c.uid, "tmp/test#{n + 1}.mp4")
          assert File.exists?(file)
          assert File.size(file) > 0
        end
      end
      should 'return success convert process' do
        assert VideoConverter.find(@c.uid)
        assert @res
        assert_equal 'finished', VideoConverter.find(@c.uid).status
      end
      should 'write log file' do
        assert File.exists?('tmp/test.log')
        assert !File.read('tmp/test.log').empty?
      end
    end

    context 'with type segmented' do
      setup do
        @c = VideoConverter.new(:input => @input, :output => [{:type => :segmented, :video_bitrate => 500, :audio_bitrate => 128, :filename => 'tmp/sd/r500.m3u8'}, {:type => :segmented, :video_bitrate => 700, :audio_bitrate => 128, :filename => 'tmp/sd/r700.m3u8'}, {:type => :segmented, :video_bitrate => 200, :audio_bitrate => 64, :filename => 'tmp/ld/r200.m3u8'}, {:type => :segmented, :video_bitrate => 300, :audio_bitrate => 60, :filename => 'tmp/ld/r300.m3u8'}, {:type => :playlist, :streams => [{'path' => 'tmp/sd/r500.m3u8', 'bandwidth' => 650}, {'path' => 'tmp/sd/r700.m3u8', 'bandwidth' => 850}], :filename => 'tmp/playlist_sd.m3u8'}, {:type => :playlist, :streams => [{'path' => 'tmp/ld/r200.m3u8', 'bandwidth' => 300}, {'path' => 'tmp/ld/r300.m3u8', 'bandwidth' => 400}], :filename => 'tmp/playlist_ld.m3u8'}])
        @res = @c.run
        @work_dir = File.join(VideoConverter::Output.work_dir, @c.uid)
      end
      should 'create chunks' do
        assert Dir.entries(File.join(@work_dir, 'tmp/sd/r500')).count > 0
        assert Dir.entries(File.join(@work_dir, 'tmp/sd/r700')).count > 0
        assert Dir.entries(File.join(@work_dir, 'tmp/ld/r200')).count > 0
        assert Dir.entries(File.join(@work_dir, 'tmp/ld/r300')).count > 0
      end
      should 'create quality playlists' do
        %w(tmp/sd/r500.m3u8 tmp/sd/r700.m3u8 tmp/ld/r200.m3u8 tmp/ld/r300.m3u8).each do |playlist|
          assert File.exists?(File.join(@work_dir, playlist))
          assert File.read(File.join(@work_dir, playlist)).include?('s-00001')
        end
      end
      should 'create group playlists' do
        playlist = File.join(@work_dir, 'tmp/playlist_sd.m3u8')
        assert File.exists?(playlist)
        assert File.read(playlist).include?('r500.m3u8')
        assert File.read(playlist).include?('r700.m3u8')
        assert !File.read(playlist).include?('r200.m3u8')
        assert !File.read(playlist).include?('r300.m3u8')
        
        playlist = File.join(@work_dir, 'tmp/playlist_ld.m3u8')
        assert File.exists?(playlist)
        assert !File.read(playlist).include?('r500.m3u8')
        assert !File.read(playlist).include?('r700.m3u8')
        assert File.read(playlist).include?('r200.m3u8')
        assert File.read(playlist).include?('r300.m3u8')
      end
    end
  end
end
