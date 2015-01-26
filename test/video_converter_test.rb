require 'test_helper'

class VideoConverterTest < Test::Unit::TestCase
  context 'convertation' do
    context 'with thumbnails' do
      setup do
        (@c = VideoConverter.new(
          :input => 'test/fixtures/test (1).mp4', 
          :outputs => [
            { :video_bitrate => 300, :filename => 'q1.mp4' }, 
            { :video_bitrate => 400, :filename => 'q2.mp4', :thumbnails => { 
              :number => 2, :offset_start => '50%', :offset_end => '20%', :presets => { :norm => '-normalize' }, :exact => true
            } },
            { :video_bitrate => 500, :filename => 'q3.mp4' }
          ]
        )).run
      end

      should 'create qualities and thumbnails' do
        3.times.each do |n|
          q = File.join(@c.outputs.first.work_dir, "q#{n + 1}.mp4")
          assert File.exists?(q)
          assert File.size(q) > 0
        end
        assert_equal %w(. .. scr004.jpg scr004_norm.jpg scr005.jpg scr005_norm.jpg).sort, Dir.entries(File.join(@c.outputs.first.work_dir, 'thumbnails')).sort
      end
    end

    context 'with aspect' do
      setup do
        (@c = VideoConverter.new(
          :input => 'test/fixtures/test (1).mp4', 
          :outputs => [
            { :video_bitrate => 300, :filename => 'res.mp4', :aspect => '4:3' }, 
          ]
        )).run
      end

      should 'change aspect' do
        m = VideoConverter.new(:input => @c.outputs.first.ffmpeg_output).inputs.first.video_stream
        assert_equal 4, m[:dar_width].to_i
        assert_equal 3, m[:dar_height].to_i
      end
    end

    context 'with aspect and resize' do
      setup do
        (@c = VideoConverter.new(
          :input => 'test/fixtures/test (1).mp4', 
          :outputs => [
            { :video_bitrate => 300, :filename => 'res.mp4', :aspect => '4:3', :height => 240 }, 
          ]
        )).run
      end

      should 'change aspect and resolution' do
        m = VideoConverter.new(:input => @c.outputs.first.ffmpeg_output).inputs.first.video_stream
        assert_equal 4, m[:dar_width].to_i
        assert_equal 3, m[:dar_height].to_i
        assert_equal 320, m[:width].to_i
        assert_equal 240, m[:height].to_i
      end
    end

    context 'with watermarks' do
      setup do
        (@c = VideoConverter.new(
          :input => 'test/fixtures/test (1).mp4', 
          :outputs => [
            { :video_bitrate => 300, :filename => 'res.mp4', :watermarks => {
              :url => 'test/fixtures/logo.png', :x=>'-3%', :y=>'-3%', :height=>'3%'
            }, :height => 240 }, 
          ]
        )).run
      end

      should 'be ok' do
        assert File.exists?(@c.outputs.first.ffmpeg_output)
      end
    end

    context 'with autocrop' do
      setup do
        (@c = VideoConverter.new(
          :input => 'test/fixtures/test_crop.mp4', 
          :outputs => [
            { :video_bitrate => 300, :filename => 'res.mp4', :crop => true }, 
          ]
        )).run
      end
      
      should 'crop' do
        m = VideoConverter.new(:input => @c.outputs.first.ffmpeg_output).inputs.first.video_stream
        assert_equal 406, m[:height].to_i
        assert_equal 720, m[:width].to_i
      end
    end
  end

  context 'segmentation' do
    context 'with transcoding' do
      context 'to HLS' do
        setup do
          VideoConverter.paral = true
          (@c = VideoConverter.new(
            "input"=>["test/fixtures/test (1).mp4"], 
            "output"=>[
              {"video_bitrate"=>676, "filename"=>"sd1.m3u8", "type"=>"segmented", "audio_bitrate"=>128, "height"=>528}, 
              {"video_bitrate"=>1172, "filename"=>"sd2.m3u8", "type"=>"segmented", "audio_bitrate"=>128, "height"=>528}, 
              {"filename"=>"playlist.m3u8", "type"=>"playlist", "streams"=>[
                {"path"=>"sd1.m3u8", "bandwidth"=>804}, {"path"=>"sd2.m3u8", "bandwidth"=>1300}
              ]}, 
              {"video_bitrate"=>1550, "filename"=>"hd1.m3u8", "type"=>"segmented", "audio_bitrate"=>48, "height"=>720}, 
              {"video_bitrate"=>3200, "filename"=>"hd2.m3u8", "type"=>"segmented", "audio_bitrate"=>128, "height"=>720}, 
              {"filename"=>"hd_playlist.m3u8", "type"=>"playlist", "streams"=>[
                {"path"=>"hd1.m3u8", "bandwidth"=>1598}, {"path"=>"hd2.m3u8", "bandwidth"=>3328}
              ]}
            ]
          )).run
        end

        should 'generate hls' do
          %w(sd1 sd2 hd1 hd2).each do |quality|
            # should create chunks
            assert_equal ['s-00000.ts', 's-00001.ts'], Dir.entries(File.join(@c.outputs.first.work_dir, quality)).delete_if { |e| ['.', '..'].include?(e) }.sort
            # TODO verify that chunks have different quality (weight)
            # should create playlists
            assert File.exists?(playlist = File.join(@c.outputs.first.work_dir, "#{quality}.m3u8"))
            # TODO verify that playlist is valid (contain all chunks and modifiers)
          end
        end
      end

      context 'to HLS AES' do
        setup do
          (@c = VideoConverter.new(
            "input"=>["test/fixtures/test (1).mp4"], 
            "output"=>[
              {"video_bitrate"=>676, "filename"=>"sd1.m3u8", "type"=>"segmented", "audio_bitrate"=>128, "height"=>528, "drm"=>"hls", "encryption_key"=>'a'*16}, 
              {"video_bitrate"=>1172, "filename"=>"sd2.m3u8", "type"=>"segmented", "audio_bitrate"=>128, "height"=>528, "drm"=>"hls", "encryption_key"=>'a'*16}, 
              {"filename"=>"playlist.m3u8", "type"=>"playlist", "streams"=>[
                {"path"=>"sd1.m3u8", "bandwidth"=>804}, {"path"=>"sd2.m3u8", "bandwidth"=>1300}
              ]}, 
              {"video_bitrate"=>1550, "filename"=>"hd1.m3u8", "type"=>"segmented", "audio_bitrate"=>48, "height"=>720, "drm"=>"hls", "encryption_key"=>'a'*16}, 
              {"video_bitrate"=>3200, "filename"=>"hd2.m3u8", "type"=>"segmented", "audio_bitrate"=>128, "height"=>720, "drm"=>"hls", "encryption_key"=>'a'*16}, 
              {"filename"=>"hd_playlist.m3u8", "type"=>"playlist", "streams"=>[
                {"path"=>"hd1.m3u8", "bandwidth"=>1598}, {"path"=>"hd2.m3u8", "bandwidth"=>3328}
              ]}
            ]
          )).run
        end

        should 'generate hls' do
          %w(sd1 sd2 hd1 hd2).each do |quality|
            # should create chunks
            assert_equal ['s-00000.ts', 's-00001.ts'], Dir.entries(File.join(@c.outputs.first.work_dir, quality)).delete_if { |e| ['.', '..'].include?(e) }.sort
            # should create playlists
            assert File.exists?(playlist = File.join(@c.outputs.first.work_dir, "#{quality}.m3u8"))
            assert File.read(playlist).include?('EXT-X-KEY:METHOD=AES-128,URI="video.key"')
            assert File.exists?(File.join(@c.outputs.first.work_dir, 'video.key'))
          end
        end
      end

      context 'to HDS' do
        setup do
          VideoConverter.paral = true
          (@c = VideoConverter.new(
            "input"=>["test/fixtures/test (1).mp4"], 
            "output"=>[
              {"video_bitrate"=>676, "filename"=>"sd1.mp4", "audio_bitrate"=>128, "height"=>360}, 
              {"video_bitrate"=>1172, "filename"=>"sd2.mp4", "audio_bitrate"=>128, "height"=>528}, 
              {"filename"=>"playlist.f4m", "type"=>"playlist", "streams"=>[
                {"path"=>"sd1.mp4", "bandwidth"=>804}, {"path"=>"sd2.mp4", "bandwidth"=>1300}
              ]}, 
              {"video_bitrate"=>1550, "filename"=>"hd1.mp4", "audio_bitrate"=>48, "height"=>720}, 
              {"video_bitrate"=>3200, "filename"=>"hd2.mp4", "audio_bitrate"=>128, "height"=>720}, 
              {"filename"=>"hd_playlist.f4m", "type"=>"playlist", "streams"=>[
                {"path"=>"hd1.mp4", "bandwidth"=>1598}, {"path"=>"hd2.mp4", "bandwidth"=>3328}
              ]}
            ]
          )).run
        end

        should 'generate hds with sync keyframes' do
          %w(sd1.mp4 sd2.mp4 playlist.f4m hd1.mp4 hd2.mp4 hd_playlist.f4m).each do |filename|
            assert File.exists?(File.join(@c.outputs.first.work_dir, "#{filename}"))
          end

          assert_equal(
            (k1 = VideoConverter::Command.new(VideoConverter::Ffmpeg.keyframes_command, :ffprobe_bin => VideoConverter::Ffmpeg.ffprobe_bin, :inputs => File.join(@c.outputs.first.work_dir, 'sd1.mp4')).capture),
            (k2 = VideoConverter::Command.new(VideoConverter::Ffmpeg.keyframes_command, :ffprobe_bin => VideoConverter::Ffmpeg.ffprobe_bin, :inputs => File.join(@c.outputs.first.work_dir, 'sd2.mp4')).capture)
          )
        end
      end
    end

    context 'without transcoding' do
      setup do
        VideoConverter.paral = false
        FileUtils.cp("test/fixtures/test (1).mp4", "test/fixtures/test (2).mp4")
        (@c = VideoConverter.new(
          :input => ["test/fixtures/test (1).mp4", "test/fixtures/test (2).mp4"], 
          :output => [
            {:filename=>"q1.m3u8", :path=>"test/fixtures/test (1).mp4", :type=>"segmented", :one_pass=>true, :video_codec=>"copy", :audio_codec=>"copy", 'bsf:v'=>"h264_mp4toannexb"}, 
            {:filename=>"q2.m3u8", :path=>"test/fixtures/test (2).mp4", :type=>"segmented", :one_pass=>true, :video_codec=>"copy", :audio_codec=>"copy", 'bsf:v'=>"h264_mp4toannexb"}, 
            {:filename=>"playlist.m3u8", :type=>"playlist", :streams=>[
              {:path=>"q1.m3u8", :bandwidth=>464}, {:path=>"q2.m3u8", :bandwidth=>928}
            ]}
          ]
        )).run
        FileUtils.rm("test/fixtures/test (2).mp4")
      end

      should 'generate hls' do
        %w(q1 q2).each do |quality|
          # should create chunks
          assert_equal ['s-00000.ts', 's-00001.ts'], Dir.entries(File.join(@c.outputs.first.work_dir, quality)).delete_if { |e| ['.', '..'].include?(e) }.sort
          # TODO verify that chunks have the same quality (weight)
          # should create playlists
          assert File.exists?(playlist = File.join(@c.outputs.first.work_dir, "#{quality}.m3u8"))
          # TODO verify that playlist is valid (contain all chunks and modifiers)
        end
      end
    end
  end

  context 'split' do
    setup do
      (@c = VideoConverter.new(
        :input => "test/fixtures/test (1).mp4",
        :output => { :segment_time => 2, :codec => 'copy', :filename => '%01d.nut' }
      )).split
    end
    should 'segment file' do
      assert_equal %w(0.nut 1.nut 2.nut 3.nut converter.log), Dir.entries(@c.outputs.first.work_dir).delete_if { |e| %w(. ..).include?(e) }.sort
    end
  end

  context 'concat' do
    setup do
      FileUtils.cp("test/fixtures/test (1).mp4", "test/fixtures/test (2).mp4")
      (@c = VideoConverter.new(
        :input => ["test/fixtures/test (1).mp4", "test/fixtures/test (2).mp4"],
        :output => { :filename => 'concat.mp4' }
      )).concat
      FileUtils.rm("test/fixtures/test (2).mp4")
    end
    should 'concat inputs' do
      assert File.exists?(@c.outputs.first.ffmpeg_output)
      assert_equal(
        VideoConverter.new(:input => "test/fixtures/test (1).mp4").inputs.first.metadata[:duration_in_ms]/1000*2,
        VideoConverter.new(:input => @c.outputs.first.ffmpeg_output).inputs.first.metadata[:duration_in_ms]/1000
      )
    end
  end
end
