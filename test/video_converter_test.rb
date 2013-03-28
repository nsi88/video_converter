require 'test_helper'

class VideoConverterTest < Test::Unit::TestCase
  context 'run' do
    setup do
      @p11 = VideoConverter::Profile.new(:bitrate => 300, :output => 'tmp/test11.mp4')
      @p12 = VideoConverter::Profile.new(:bitrate => 400, :output => 'tmp/test12.mp4')
      @p21 = VideoConverter::Profile.new(:bitrate => 700, :output => 'tmp/test21.mp4')
      @p22 = VideoConverter::Profile.new(:bitrate => 700, :output => 'tmp/test22.mp4')
      @c = VideoConverter.new(:input => 'test/fixtures/test.mp4', :profile => [[@p11, @p12], [@p21, @p22]], :verbose => false, :log => 'tmp/test.log')
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
end
