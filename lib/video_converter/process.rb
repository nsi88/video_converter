# encoding: utf-8

module VideoConverter
  class Process
    attr_accessor :uid, :status, :progress, :pid

    class << self
      attr_accessor :path
    end
    self.path = 'tmp/processes'

    def initialize uid
      self.uid = uid
      Dir.mkdir(self.class.path) unless Dir.exists?(self.class.path)
    end

    [:status, :progress, :pid].each do |attr|
      define_method(attr) { File.open(send("#{attr}_file".to_sym), 'r') { |f| f.read } rescue nil }
      define_method("#{attr}=") { |value| File.open(send("#{attr}_file".to_sym), 'w') { |f| f.write value } }
    end

    def stop
      `pkill -P #{pid}`
    end

    private

    [:status, :progress, :pid].each do |attr|
      define_method("#{attr}_file".to_sym) { File.join self.class.path, "#{uid}_#{attr}" }
    end
  end
end
