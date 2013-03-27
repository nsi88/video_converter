# encoding: utf-8

module VideoConverter
  class Base
    attr_accessor :input, :profile, :one_pass, :type, :debug

    def initialize params
      [:input, :profile].each do |needed_param|
        self.send("#{needed_param}=", params[needed_param]) or raise ArgumentError.new("#{needed_param} is needed")
      end
      self.one_pass = params[:one_pass] || VideoConverter.one_pass
      self.type = params[:type] ? params[:type].to_sym : VideoConverter.type
      self.debug = params[:debug] || VideoConverter.debug
      raise ArgumentError.new("Incorrect type #{params[:type]}. Should one of mp4, hls") unless [:mp4, :hls].include?(type)
      require 'fileutils'
      [profile].flatten.each{|p| FileUtils.mkdir_p File.dirname(p.to_hash[:output])}
    end

    def run
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
          execute quality_command
        end
      end
    end

    private

    def groups
      groups = profile.is_a?(Array) ? profile : [profile]
      groups.map do |qualities|
        qualities.is_a?(Array) ? qualities : [qualities]
      end
    end

    def prepare_command command, profile
      res = command.gsub('%{bin}', VideoConverter::Ffmpeg.bin).gsub('%{input}', input)
      profile.to_hash.each do |param, value|
        res.gsub! "%{#{param}}", value.to_s
      end
      res
    end

    def execute command
      puts command
      `#{command}` unless debug
    end

  end
end
