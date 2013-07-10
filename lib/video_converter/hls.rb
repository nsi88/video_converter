# encoding: utf-8

module VideoConverter
  class Hls
    attr_accessor :ffmpeg_bin, :input, :output, :playlist_dir, :log, :verbose

    def initialize params
      self.ffmpeg_bin = params[:ffmpeg_bin] || Ffmpeg.bin
      %w(input output).each { |param| self.send("#{param}=", params[param.to_sym]) or raise "#{param} is needed" }
      self.playlist_dir = if params[:playlist_dir]
        params[:playlist_dir]
      elsif !input.match(/^https?:\/\//)
        File.dirname(input)
      end
      self.log = params[:log] || '/dev/null'
      self.verbose = params[:verbose]
    end

    def concat
      chunks = parse_playlist rescue []
      raise "Empty or invalid playlist #{input}" if chunks.empty?
      output_dir = File.dirname(output)
      `mkdir -p #{output_dir}` unless Dir.exists?(output_dir)
      concat_file = File.join(output_dir, 'concat.ts')
      `rm #{concat_file}` if File.exists? concat_file
      chunks.each do |chunk|
        if playlist_dir && File.exists?(local_chunk = File.join(playlist_dir, chunk))
          puts "Copy #{local_chunk} to #{concat_file}" if verbose
          `cat #{local_chunk} >> #{concat_file}`
        else
          chunk = File.join(File.dirname(input), chunk) unless chunk.match(/(^https?:\/\/)|(^\/)/)
          puts "Download #{chunk} to #{concat_file}" if verbose
          `cd #{output_dir} && wget #{chunk} 1>>%{log} 2>&1 && cat #{File.basename(chunk)} >> #{concat_file} && rm #{File.basename(chunk)}` 
        end
      end
      raise "Cannot download chunks from #{input}" unless File.exists?(concat_file) && File.size(concat_file) > 0
      puts "Convert #{concat_file}" if verbose
      `#{ffmpeg_bin} -i #{concat_file} -vcodec copy -acodec copy -f mpegts pipe:1 2>>/dev/null | #{ffmpeg_bin} -y -i - -acodec copy -vcodec copy -absf aac_adtstoasc -f mp4 #{output} 1>>#{log} 2>&1`
      `rm #{concat_file}`
      output
    end

    private

    def parse_playlist
      require 'open-uri'
      open(input) { |f| f.read }.scan(/EXTINF:[\d.]+.*?\n(.*?)\n/).flatten
    end
  end
end
