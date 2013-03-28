# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input, :profile, :one_pass, :type, :paral, :debug, :verbose, :log, :id, :playlist_dir

    def initialize params
      self.one_pass = params[:one_pass].nil? ? VideoConverter.one_pass : params[:one_pass]
      self.type = params[:type].nil? ? VideoConverter.type : params[:type].to_sym
      self.paral = params[:paral].nil? ? VideoConverter.paral : params[:paral]
      self.debug = params[:debug].nil? ? VideoConverter.debug : params[:debug]
      self.verbose = params[:verbose].nil? ? VideoConverter.verbose : params[:verbose]
      self.log = params[:log].nil? ? '/dev/null' : params[:log]
      needed_params = [:input, :profile]
      needed_params << :playlist_dir if type == :hls
      needed_params.each do |needed_param|
        self.send("#{needed_param}=", params[needed_param]) or raise ArgumentError.new("#{needed_param} is needed")
      end
      raise ArgumentError.new("Incorrect type #{params[:type]}. Should one of mp4, hls") unless [:mp4, :hls].include?(type)
      require 'fileutils'
      # for hls output is folder, for mp4 - file
      if type == :hls
        [profile].flatten.each{|p| FileUtils.mkdir_p p.to_hash[:output]}
      else
        [profile].flatten.each{|p| FileUtils.mkdir_p File.dirname(p.to_hash[:output])}
      end
      FileUtils.mkdir_p File.dirname(log) unless log == '/dev/null'
      self.id = object_id
    end

    def run
      process = VideoConverter::Process.new(id)
      process.pid = `cat /proc/self/stat`.split[3]
      actions = [:convert]
      actions << :live_segment if type == :hls
      actions.each do |action|
        process.status = action.to_s
        process.progress = 0
        res = send action
        if res
          process.status = "#{action}_success"
        else
          process.status = "#{action}_error"
          return false
        end
      end
      true
    end

    private

    def convert
      res = true
      threads = []
      groups.each do |qualities|
        unless one_pass
          group_command = prepare_command VideoConverter::Ffmpeg.first_pass_command, qualities.first.to_hash
          res &&= execute group_command
        end
        qualities.each do |quality|
          q = quality.to_hash.merge(:output => File.join(quality.to_hash[:output], File.basename(input)))
          if one_pass
            quality_command = prepare_command VideoConverter::Ffmpeg.one_pass_command, q
          else
            quality_command = prepare_command VideoConverter::Ffmpeg.second_pass_command, q
          end
          if paral
            threads << Thread.new { res &&= execute quality_command }
          else
            res &&= execute quality_command
          end
        end
      end
      threads.each { |t| t.join } if paral
      res
    end

    def live_segment
      res = true
      threads = []
      [profile].flatten.each do |profile|
        params = {:segment_length => VideoConverter::LiveSegmenter.segment_length, :filename_prefix => VideoConverter::LiveSegmenter.filename_prefix, :encoding_profile => VideoConverter::LiveSegmenter.encoding_profile}.merge(profile.to_hash)
        params[:input] = File.join(params[:output], File.basename(input))
        command = prepare_command VideoConverter::LiveSegmenter.command, params
        command += "; rm #{params[:input]}"
        if paral
          threads << Thread.new { res &&= execute command; }
        else
          res &&= execute command
        end
      end
      threads.each { |t| t.join } if paral
      res
    end

    def groups
      groups = profile.is_a?(Array) ? profile : [profile]
      groups.map do |qualities|
        qualities.is_a?(Array) ? qualities : [qualities]
      end
    end

    def prepare_command command, params
      res = command.clone
      {:ffmpeg_bin => VideoConverter::Ffmpeg.bin, :live_segmenter_bin => VideoConverter::LiveSegmenter.bin, :input => input, :log => log}.merge(params).each do |param, value|
        res.gsub! "%{#{param}}", value.to_s
      end
      res
    end

    def execute command
      puts command if verbose
      if debug
        true
      else
        system command
      end
    end

  end
end
