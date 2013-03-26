require 'test_helper'

class FfmpegTest < Test::Unit::TestCase
  setup do
    @input = 'test/fixtures/test.mp4'
    @bitrate = 700
    @profile = true
    @bin = 'bin/stubs/ffmpeg_stub'
    @aspect = '16:9'
    @output = 'test/tmp/test.mp4'
    @opts = {:input => @input, :bitrate => @bitrate, :profile => @profile, :bin => @bin, :aspect => @aspect}
  end

  context 'constructor' do
    should 'create instance only with correct options' do
      assert_raise(ArgumentError) { VideoConverter::Ffmpeg.new }
      assert_raise(ArgumentError) { VideoConverter::Ffmpeg.new(:input => @input) }
      assert_raise(ArgumentError) { VideoConverter::Ffmpeg.new(:input => @input, :bitrate => @bitrate) }
      assert VideoConverter::Ffmpeg.new(:input => @input, :bitrate => @bitrate, :profile => @profile)
      assert_raise(ArgumentError) { VideoConverter::Ffmpeg.new(:input => 'test/fixtures/not_existed_file.mp4', :bitrate => @bitrate, :profile => @profile) }
    end

    should 'set default values if any opts are not passed' do
      @ffmpeg = VideoConverter::Ffmpeg.new(:input => @input, :bitrate => @bitrate, :profile => @profile)
      assert_equal 'ffmpeg', @ffmpeg.bin
      assert !@ffmpeg.one_pass
      assert_equal 1, @ffmpeg.threads
      assert_equal '4:3', @ffmpeg.aspect
    end

    should 'set opts' do
      @ffmpeg = VideoConverter::Ffmpeg.new(@opts.merge(:one_pass => true))
      assert_equal @bin, @ffmpeg.bin
      assert @ffmpeg.one_pass
      assert @aspect, @ffmpeg.aspect
    end
  end

  context 'one pass command' do
    setup do
      @ffmpeg = VideoConverter::Ffmpeg.new(@opts.merge(:one_pass => true))
    end

    should 'return command string with passed attributes' do
      assert @ffmpeg.one_pass_command(@output).include?("-i #{@input}")
      assert @ffmpeg.one_pass_command(@output).include?("-b #{@bitrate}")
      assert_equal 0, @ffmpeg.one_pass_command(@output).index(@bin)
      assert @ffmpeg.one_pass_command(@output).include?("-aspect #{@aspect}")
    end
  end

  context 'first pass command' do
    setup do
      @ffmpeg = VideoConverter::Ffmpeg.new(@opts)
    end

    should 'return command string with passed attributes' do
      assert @ffmpeg.first_pass_command(@output).include?('-pass 1')
    end
  end

  context 'second pass command' do
    setup do
      @ffmpeg = VideoConverter::Ffmpeg.new(@opts)
    end

    should 'return command string with passed attributes' do
      assert @ffmpeg.second_pass_command(@output).include?('-pass 2')
    end
  end

end
