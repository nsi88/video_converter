require 'test_helper'

class VideoConverterTest < Test::Unit::TestCase
  context 'run' do
    setup do
      @input_file = 'test/fixtures/test.mp4'
      @input_url = 'http://techslides.com/demos/sample-videos/small.mp4'
    end
    context 'with default type' do
      setup do
        @c = VideoConverter.new('input' => @input_file, 'output' => [{'video_bitrate' => 300, 'filename' => 'tmp/test1.mp4'}, {'video_bitrate' => 700, :filename => 'tmp/test2.mp4'}], 'log' => 'tmp/test.log')
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
        @c = VideoConverter.new(:input => @input_file, :output => [{:type => :segmented, :video_bitrate => 500, :audio_bitrate => 128, :filename => 'tmp/sd/r500.m3u8'}, {:type => :segmented, :video_bitrate => 700, :audio_bitrate => 128, :filename => 'tmp/sd/r700.m3u8'}, {:type => :segmented, :video_bitrate => 200, :audio_bitrate => 64, :filename => 'tmp/ld/r200.m3u8'}, {:type => :segmented, :video_bitrate => 300, :audio_bitrate => 60, :filename => 'tmp/ld/r300.m3u8'}, {:type => :playlist, :streams => [{'path' => 'tmp/sd/r500.m3u8', 'bandwidth' => 650}, {'path' => 'tmp/sd/r700.m3u8', 'bandwidth' => 850}], :filename => 'tmp/playlist_sd.m3u8'}, {:type => :playlist, :streams => [{'path' => 'tmp/ld/r200.m3u8', 'bandwidth' => 300}, {'path' => 'tmp/ld/r300.m3u8', 'bandwidth' => 400}], :filename => 'tmp/playlist_ld.m3u8'}])
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
      should 'clear tmp files' do
        [200, 300, 500, 700].each do |q|
          assert !File.exists?(File.join(@work_dir, "r#{q}.ts"))
        end
      end
    end

    context 'only segment some files' do
      setup do
        # prepare files
        @c1 = VideoConverter.new(:input => @input_file, :output => [{:video_bitrate => 300, :filename => 'sd/1.mp4'}, {:video_bitrate => 400, :filename => 'sd/2.mp4'}, {:video_bitrate => 500, :filename => 'hd/1.mp4'}, {:video_bitrate => 600, :filename => 'hd/2.mp4'}])
        @c1.run
        @input1, @input2, @input3, @input4 = @c1.output_array.outputs.map { |output| output.local_path }
        # test segmentation
        @c2 = VideoConverter.new(:input => [@input1, @input2, @input3, @input4], :output => [
          {:path => @input1, :type => :segmented, :filename => '1.m3u8', :copy_video => true}, 
          {:path => @input2, :type => :segmented, :filename => '2.m3u8', :copy_video => true}, 
          {:path => @input3, :type => :segmented, :filename => '3.m3u8', :copy_video => true}, 
          {:path => @input4, :type => :segmented, :filename => '4.m3u8', :copy_video => true}, 
          {:type => :playlist, :streams => [{:path => '1.m3u8'}, {:path => '2.m3u8'}], :filename => 'playlist1.m3u8'}, 
          {:type => :playlist, :streams => [{:path => '3.m3u8'}, {:path => '4.m3u8'}], :filename => 'playlist2.m3u8'}
        ], :clear_tmp => false)
        @res = @c2.run
        @work_dir = File.join(VideoConverter::Output.work_dir, @c2.uid)
      end
      should 'create chunks' do
        4.times do |n|
          assert Dir.entries(File.join(@work_dir, "#{n + 1}")).count > 0
        end
      end
      should 'create quality playlists' do
        4.times do |n|
          playlist = "#{n + 1}.m3u8"
          assert File.exists?(File.join(@work_dir, playlist))
          assert File.read(File.join(@work_dir, playlist)).include?('s-00001')
        end
      end
      should 'create group playlist' do
        playlist = File.join(@work_dir, 'playlist1.m3u8')
        assert File.exists?(playlist)
        assert File.read(playlist).include?('1.m3u8')
        assert File.read(playlist).include?('2.m3u8')

        playlist = File.join(@work_dir, 'playlist2.m3u8')
        assert File.exists?(playlist)
        assert File.read(playlist).include?('3.m3u8')
        assert File.read(playlist).include?('4.m3u8')
      end
      should 'not convert inputs' do
        assert_equal VideoConverter::Input.new(@input1).metadata[:video_bitrate_in_kbps], VideoConverter::Input.new(File.join(@work_dir, '1.ts')).metadata[:video_bitrate_in_kbps]
        assert_equal VideoConverter::Input.new(@input2).metadata[:video_bitrate_in_kbps], VideoConverter::Input.new(File.join(@work_dir, '2.ts')).metadata[:video_bitrate_in_kbps]
        assert_equal VideoConverter::Input.new(@input3).metadata[:video_bitrate_in_kbps], VideoConverter::Input.new(File.join(@work_dir, '3.ts')).metadata[:video_bitrate_in_kbps]
        assert_equal VideoConverter::Input.new(@input4).metadata[:video_bitrate_in_kbps], VideoConverter::Input.new(File.join(@work_dir, '4.ts')).metadata[:video_bitrate_in_kbps]
      end
    end
  end
end
