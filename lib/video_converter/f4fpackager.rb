# encoding: utf-8

module VideoConverter
  class F4fpackager
    class << self
      attr_accessor :bin, :command, :help_command, :inspect_index_command
    end
    
    self.bin = '/usr/local/bin/f4fpackager'
    self.command = '%{bin} %{options} 1>>%{log} 2>&1 || exit 1'
    self.help_command = '%{bin} --help'
    self.inspect_index_command = '%{bin} --input-file %{input_file} --inspect-index'
    
    def self.run(output)
      manifest = nil
      output.streams.each_with_index do |stream, index|
        VideoConverter::Command.new(command, prepare_params(output.options.merge({
          :input_file => File.join(output.work_dir, stream[:path]),
          :output_path => output.work_dir,
          :bitrate => stream[:bandwidth],
          :manifest_file => manifest,
          :log => output.log
        }))).execute or return false
        FileUtils.rm manifest if manifest
        quality = File.basename(stream[:path], '.*')
        manifest = File.join(output.work_dir, quality + '.f4m')
        # extract fragments
        extract_fragments(output, quality) unless output.no_fragments
      end
      FileUtils.mv(manifest, File.join(output.work_dir, output.filename))
      true
    end

    private

    def self.allowed_options
      @allowed_options ||= Command.new(help_command, :bin => bin).capture.scan(/--([\w-]+)/).flatten.uniq
    end

    def self.prepare_params options
      {
        :bin => bin,
        :input_file => options[:input_file],
        :options => Hash[*allowed_options.map do |option|
          if value = options[option.gsub('-', '_').to_sym]
            ['--' + option, value]
          end
        end.compact.flatten],
        :log => options[:log]
      }
    end

    def self.extract_fragments output, quality
      f4x = File.join(output.work_dir, "#{quality}Seg1.f4x") 
      f4f = f4x.sub('.f4x', '.f4f')
      next_fragment_offset = File.size(f4f) + 1
      Command.new(inspect_index_command, prepare_params(:input_file => File.join(output.work_dir, "#{quality}Seg1.f4x"))).capture
        .scan(/time = (\d+), segment = (\d+), fragment = (\d+), afra-offset = (\d+), offset-from-afra = (\d+)/).reverse
        .each do |fragment| 
          offset = fragment[3].to_i + fragment[4].to_i
          File.open(File.join(output.work_dir, "#{quality}Seg#{fragment[1]}-Frag#{fragment[2]}"), 'wb') { |f| f.write IO.read(f4f, next_fragment_offset - offset, offset) }
          next_fragment_offset = offset
        end
      FileUtils.rm f4x
      FileUtils.rm f4f
    end
  end
end