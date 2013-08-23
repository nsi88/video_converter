# encoding: utf-8

module VideoConverter
  class Process
    attr_accessor :uid, :status, :progress, :status_progress, :pid, :process_dir, :status_progress_koefs

    class << self
      attr_accessor :process_dir, :collect_progress_interval
    end
    self.process_dir = '/tmp/video_converter_process'
    self.collect_progress_interval = 10

    def self.find uid
      if Dir.exists?(File.join(process_dir, uid))
        new uid
      else
        nil
      end
    end

    def initialize uid, output_array = nil
      self.uid = uid
      self.process_dir = File.join(self.class.process_dir, uid)

      unless Dir.exists? process_dir
        FileUtils.mkdir_p process_dir
        self.pid = `cat /proc/self/stat`.split[3]
        self.status = 'started'
        self.progress = self.status_progress = 0
      end

      if output_array
        self.status_progress_koefs = {}
        self.status_progress_koefs[:screenshot] = 0.05 if output_array.outputs.detect { |o| o.thumbnails }
        self.status_progress_koefs[:segment] = 0.1 if output_array.playlists.any?
        self.status_progress_koefs[:convert] = 1 - status_progress_koefs.values.inject(0, :+)
      else
        self.status_progress_koefs = { :screenshot => 0.05, :segment => 0.1, :convert => 0.85 }
      end
    end

    # attr are saved in local file
    def get_attr attr
      File.open(File.join(process_dir, "#{attr}.txt"), 'r') { |f| f.read } rescue nil
    end
    def set_attr attr, value
      File.open(File.join(process_dir, "#{attr}.txt"), 'w') { |f| f.write value }
    end

    [:progress, :status_progress, :pid].each do |attr|
      define_method attr do
        get_attr attr
      end
      define_method "#{attr}=" do |value|
        set_attr attr, value
      end
    end
        
    def status
      get_attr :status
    end

    def status= value
      set_attr :status, value
      FileUtils.mkdir_p progress_dir if %w(convert).include?(value.to_s)
      self.progress = self.status_progress = 1 if value.to_s == 'finished'
    end

    def stop
      `pkill -P #{pid}`
    end

    def collect_progress progress
      self.status_progress = progress
      self.progress = progress * status_progress_koefs[status.to_sym].to_f
    end

    def progress_dir
      File.join process_dir, 'progress', status
    end
  end
end
