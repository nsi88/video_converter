# encoding: utf-8

module VideoConverter
  class Profile
    class << self
      attr_accessor :needed_params, :default_params
    end

    self.needed_params = [:bitrate, :output]
    self.default_params = {:aspect => '4:3', :threads => 1}

    attr_accessor :params

    def initialize params
      self.class.needed_params.each do |needed_param|
        raise ArgumentError.new("#{needed_param} is needed") unless params[needed_param]
      end
      self.params = self.class.default_params.merge params
    end

    def to_hash
      params
    end
  end
end
