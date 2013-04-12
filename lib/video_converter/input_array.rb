# encoding: utf-8

module VideoConverter
  class InputArray
    attr_accessor :inputs

    def initialize inputs
      self.inputs = (inputs.is_a?(Array) ? inputs : [inputs]).map { |input| Input.new(input) }
    end
  end
end
