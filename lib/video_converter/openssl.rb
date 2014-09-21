module VideoConverter
  class OpenSSL
    class << self
      attr_accessor :bin, :command, :encryption_type
    end

    #TODO locate openssl
    self.bin = 'openssl'
    self.encryption_type = 'aes-128-cbc'
    self.command = '%{bin} %{encryption_type} -e -in %{chunk} -out %{encrypted_chunk} -nosalt -iv %{initialization_vector} -K %{encryption_key}'

    def self.run(output)
      success = true
      playlist = File.join(output.work_dir, output.filename)
      File.write(playlist, File.read(playlist).sub("#EXTM3U\n", "#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"#{OpenSSL.get_encryption_key_path(output)}\"\n"))
      encryption_dir = FileUtils.mkdir_p("#{output.chunks_dir}_encrypted").first
      chunks = Dir::glob(File.join(output.chunks_dir, "*.ts")).sort do |c1, c2|
        File.basename(c1).match(/\d+/).to_s.to_i <=> File.basename(c2).match(/\d+/).to_s.to_i
      end
      chunks.each_with_index do |chunk, index|
        initialization_vector = "%032x" % index
        success &&= Command.new(command, prepare_params( :chunk => chunk, :encrypted_chunk => File.join(encryption_dir,File.basename(chunk)),
                                                         :initialization_vector => initialization_vector, :encryption_key => OpenSSL.get_encryption_key(output) )).execute
      end
      remove_old_dir(output) if success
      success
    end

    def self.get_encryption_key_path(output)
      if output.encryption_key
        File.open(File.join(output.work_dir,'video.key'), 'wb') { |f| f.write output.encryption_key }
        'video.key'
      elsif output.encryption_key_url
        uri = URI(output.encryption_key_url)
        File.open(File.join(output.work_dir,'url.video.key'), 'wb') { |f| f.puts Net::HTTP.get(uri.host, uri.path) }
        output.encryption_key_url
      else
        nil
      end
    end

    def self.get_encryption_key(output)
      if output.encryption_key
        File.join(output.work_dir, "video.key")
      elsif output.encryption_key_url
        File.join(output.work_dir, "url.video.key")
      else
        nil
      end
    end

    private

    def self.prepare_params(params)
      {
        :bin => bin,
        :encryption_type => encryption_type,
        :chunk => params[:chunk],
        :encrypted_chunk => params[:encrypted_chunk],
        :initialization_vector => params[:initialization_vector],
        :encryption_key => `hexdump -e '16/1 "%02x"' #{params[:encryption_key]}`
      }
    end

    def self.remove_old_dir(output)
      FileUtils.rm_r(output.chunks_dir)
      FileUtils.mv("#{output.chunks_dir}_encrypted", output.chunks_dir)
      FileUtils.rm (File.join(output.work_dir,'url.video.key')) if File.exists?(File.join(output.work_dir,'url.video.key'))
    end

  end
end
