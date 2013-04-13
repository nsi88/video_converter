# encoding: utf-8

module VideoConverter
  class OutputArray
    attr_accessor :outputs, :uid

    def initialize outputs, uid
      self.uid = uid
      self.outputs = (outputs.is_a?(Array) ? outputs : [outputs]).map { |output| Output.new(output.merge(:uid => uid)) }
      self.outputs.select { |output| output.type == :playlist }.each do |playlist|
        stream_names = playlist.streams.map { |stream| stream[:path] }
        playlist.items = self.outputs.select { |output| [:standard, :segmented].include?(output.type) && stream_names.include?(output.filename) }
        playlist.items.each { |item| item.playlist = playlist }
      end
    end

    def playlists
      outputs.select { |output| output.type == :playlist }
    end
  end
end   
