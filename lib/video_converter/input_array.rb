# encoding: utf-8

module VideoConverter
  class InputArray
    attr_accessor :inputs

    def initialize inputs, output_array
      self.inputs = (inputs.is_a?(Array) ? inputs : [inputs]).map { |input| Input.new(input) }
      output_array.outputs.each do |output|
        if [:standard, :segmented].include? output.type
          self.inputs[self.inputs.index { |input| input.to_s == Shellwords.escape(output.path.to_s).gsub("\\\\","\\") }.to_i].outputs << output
        end
      end
      self.inputs.each do |input|
        output_array.playlists.each do |playlist|
          unless (groups = input.outputs.select { |output| output.playlist == playlist }).empty?
            input.output_groups << groups
          end
        end
        input.outputs.select { |output| output.playlist.nil? }.each { |output| input.output_groups << [output] }
      end
    end
  end
end
