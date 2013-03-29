# encoding: utf-8

module VideoConverter
  class LiveSegmenter
    class << self
      attr_accessor :bin, :chunks_command, :segment_length, :filename_prefix, :encoding_profile, :delete_input
    end
    
    self.bin = '/usr/local/bin/live_segmenter'

    self.segment_length = 10

    self.filename_prefix = 's'
    
    self.encoding_profile = 's'

    self.delete_input = true

    self.chunks_command = '%{ffmpeg_bin} -i %{input} -vcodec libx264 -acodec copy -f mpegts pipe:1 2>>/dev/null | %{bin} %{segment_length} %{output_dir} %{filename_prefix} %{encoding_profile}'

    attr_accessor :files, :playlist_dir, :paral, :segment_length, :filename_prefix, :encoding_profile, :delete_input

    def initialize params
      [:files, :playlist_dir].each do |param|
        self.send("#{param}=", params[param])
      end
      self.files = [files] if files.is_a? String
      if files.is_a? Array
        self.files = Hash[*files.map { |file| [file, file.sub(Regexp.new(File.extname(file) + '$'), '')] }.flatten]
      end
      files.values.each { |output_dir| FileUtils.mkdir_p output_dir }
      
      [:segment_length, :filename_prefix, :encoding_profile, :delete_input].each do |param|
        self.send("#{param}=", params[param] || self.class.send(param))
      end
    end

    def run
      res = true
      threads = []
      files.each do |input, output|
        if paral
          threads << Thread.new { res &&= make_chunks(input, output) }
        else
          res &&= make_chunks(input, output)
        end
      end
      res
    end

    private

    def make_chunks input, output
      params = {}
      [:segment_length, :filename_prefix, :encoding_profile].each { |param| params[param] = self.send(param) }
      command = Command.new self.class.chunks_command, params.merge(:input => input, :output_dir => output).merge(common_params)
      res = command.execute
      FileUtils.rm input if delete_input
      res
    end

    def common_params
      { :ffmpeg_bin => Ffmpeg.bin, :bin => self.class.bin }
    end
  end
end
