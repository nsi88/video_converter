require 'test_helper'

class VideoConverterTest < Test::Unit::TestCase
  setup do
    VideoConverter::Command.verbose = true
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
