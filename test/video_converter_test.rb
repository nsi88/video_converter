require 'test_helper'

class VideoConverterTest < Test::Unit::TestCase
  context 'run' do
    setup do
      @input = 'test/fixtures/test.mp4'
    end

    context 'with type mp4' do
      setup do
        @profiles = []
        @profiles << (@p11 = VideoConverter::Profile.new(:bitrate => 300, :file => 'tmp/test11.mp4'))
        @profiles << (@p12 = VideoConverter::Profile.new(:bitrate => 400, :file => 'tmp/test12.mp4'))
        @profiles << (@p21 = VideoConverter::Profile.new(:bitrate => 700, :file => 'tmp/test21.mp4'))
        @profiles << (@p22 = VideoConverter::Profile.new(:bitrate => 700, :file => 'tmp/test22.mp4'))
        @c = VideoConverter.new(:input => @input, :profile => [[@p11, @p12], [@p21, @p22]], :verbose => false, :log => 'tmp/test.log', :type => :mp4)
        @res = @c.run
      end
      should 'convert files' do
        4.times do |n|
          file = "tmp/test#{n / 2 + 1}#{n.even? ? 1 : 2}.mp4"
          assert File.exists?(file)
          assert File.size(file) > 0
        end
      end
      should 'return success convert process' do
        assert VideoConverter.find(@c.id)
        assert @res
        assert_equal 'convert_success', VideoConverter.find(@c.id).status
      end
      should 'write log file' do
        assert File.exists?('tmp/test.log')
        assert !File.read('tmp/test.log').empty?
      end
    end

    context 'with type hls' do
      setup do
        @profiles = []
        @profiles << (@p11 = VideoConverter::Profile.new(:bitrate => 300, :dir => 'tmp/test11'))
        @profiles << (@p12 = VideoConverter::Profile.new(:bitrate => 400, :dir => 'tmp/test12'))
        @profiles << (@p21 = VideoConverter::Profile.new(:bitrate => 700, :dir => 'tmp/test21'))
        @profiles << (@p22 = VideoConverter::Profile.new(:bitrate => 700, :dir => 'tmp/test22'))
      end
      context '' do
        setup do
          @c = VideoConverter.new(:input => @input, :profile => [[@p11, @p12], [@p21, @p22]], :verbose => false, :log => 'tmp/test.log', :type => :hls, :playlist_dir => 'tmp')
          @res = @c.run
        end
        should 'create chunks' do
          @profiles.each do |profile|
            assert File.exists?(File.join(profile.to_hash[:dir], 's-00001.ts'))
          end
        end
        should 'create quality playlists' do
          @profiles.each do |profile|
            assert File.exists?(File.join(File.dirname(profile.to_hash[:dir]), File.basename(profile.to_hash[:dir]) + '.m3u8'))
          end
        end
        should 'create group playlists' do
          playlist1 = File.join('tmp', 'playlist1.m3u8')
          playlist2 = File.join('tmp', 'playlist2.m3u8')
          assert File.exists? playlist1
          assert File.exists? playlist2
          assert File.read(playlist1).include?('test11')
          assert File.read(playlist1).include?('test12')
          assert !File.read(playlist1).include?('test21')
          assert !File.read(playlist1).include?('test22')
          assert File.read(playlist2).include?('test21')
          assert File.read(playlist2).include?('test22')
          assert !File.read(playlist2).include?('test11')
          assert !File.read(playlist2).include?('test12')
        end
      end

      context 'with no_convert flag' do
        setup do
          @c = VideoConverter.new(:profile => VideoConverter::Profile.new(:file => 'test/fixtures/test.mp4', :dir => '/tmp/test', :bitrate => 300), :no_convert => true, :type => :hls, :playlist_dir => 'tmp')
          @res = @c.run
        end
        should 'return true' do
          assert @res
        end
        should 'create needed files' do
          assert File.exists? '/tmp/test/s-00001.ts'
        end
      end
    end
  end
end
