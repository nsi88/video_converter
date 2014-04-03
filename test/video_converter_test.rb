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
              :number => 2, :offset_start => '5%', :offset_end => '5%', :presets => { :norm => '-normalize' }
            } },
            { :video_bitrate => 500, :filename => 'q3.mp4' }
          ]
        )).run
      end

      should 'create qualities and thumbnails' do
        3.times.each do |n|
          q = File.join(VideoConverter::Output.work_dir, @c.uid, "q#{n + 1}.mp4")
          assert File.exists?(q)
          assert File.size(q) > 0
        end
        assert_equal %w(. .. scr004.jpg scr004_norm.jpg scr005.jpg scr005_norm.jpg).sort, Dir.entries(File.join(VideoConverter::Output.work_dir, @c.uid, 'thumbnails')).sort
      end
    end
  end

  context 'segmentation' do
    context 'with transcoding' do
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
          assert_equal ['s-00001.ts', 's-00002.ts'], Dir.entries(File.join(VideoConverter::Output.work_dir, @c.uid, quality)).delete_if { |e| ['.', '..'].include?(e) }.sort
          # TODO verify that chunks have different quality (weight)
          # should create playlists
          assert File.exists?(playlist = File.join(VideoConverter::Output.work_dir, @c.uid, "#{quality}.m3u8"))
          # TODO verify that playlist is valid (contain all chunks and modifiers)
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
            {:filename=>"q1.m3u8", :path=>"test/fixtures/test (1).mp4", :type=>"segmented", :one_pass=>true, :video_codec=>"copy", :audio_codec=>"copy", :bitstream_format=>"h264_mp4toannexb"}, 
            {:filename=>"q2.m3u8", :path=>"test/fixtures/test (2).mp4", :type=>"segmented", :one_pass=>true, :video_codec=>"copy", :audio_codec=>"copy", :bitstream_format=>"h264_mp4toannexb"}, 
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
          assert_equal ['s-00001.ts', 's-00002.ts', 's-00003.ts'], Dir.entries(File.join(VideoConverter::Output.work_dir, @c.uid, quality)).delete_if { |e| ['.', '..'].include?(e) }.sort
          # TODO verify that chunks have the same quality (weight)
          # should create playlists
          assert File.exists?(playlist = File.join(VideoConverter::Output.work_dir, @c.uid, "#{quality}.m3u8"))
          # TODO verify that playlist is valid (contain all chunks and modifiers)
        end
      end
    end
  end
end
