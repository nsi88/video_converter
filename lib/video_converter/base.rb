# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input, :profile, :one_pass, :type, :paral, :debug, :verbose, :log

    def initialize params
      [:input, :profile].each do |needed_param|
        self.send("#{needed_param}=", params[needed_param]) or raise ArgumentError.new("#{needed_param} is needed")
      end
      self.one_pass = params[:one_pass].nil? ? VideoConverter.one_pass : params[:one_pass]
      self.type = params[:type].nil? ? VideoConverter.type : params[:type].to_sym
      self.paral = params[:paral].nil? ? VideoConverter.paral : params[:paral]
      self.debug = params[:debug].nil? ? VideoConverter.debug : params[:debug]
      self.verbose = params[:verbose].nil? ? VideoConverter.verbose : params[:verbose]
      self.log = params[:log].nil? ? '/dev/null' : params[:log]
      raise ArgumentError.new("Incorrect type #{params[:type]}. Should one of mp4, hls") unless [:mp4, :hls].include?(type)
      require 'fileutils'
      [profile].flatten.each{|p| FileUtils.mkdir_p File.dirname(p.to_hash[:output])}
      FileUtils.mkdir_p File.dirname(log) unless log == '/dev/null'
    end

    def run
      threads = []
      groups.each do |qualities|
        unless one_pass
          group_command = prepare_command VideoConverter::Ffmpeg.first_pass_command, qualities.first
          execute group_command
        end
        qualities.each do |quality|
          if one_pass
            quality_command = prepare_command VideoConverter::Ffmpeg.one_pass_command, quality
          else
            quality_command = prepare_command VideoConverter::Ffmpeg.second_pass_command, quality
          end
          if paral
            threads << Thread.new { execute quality_command }
          else
            execute quality_command
          end
        end
      end
      threads.each { |t| t.join } if paral
    end

    private

    def groups
      groups = profile.is_a?(Array) ? profile : [profile]
      groups.map do |qualities|
        qualities.is_a?(Array) ? qualities : [qualities]
      end
    end

    def prepare_command command, profile
      res = command.gsub('%{bin}', VideoConverter::Ffmpeg.bin).gsub('%{input}', input).gsub('%{log}', log)
      profile.to_hash.each do |param, value|
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
