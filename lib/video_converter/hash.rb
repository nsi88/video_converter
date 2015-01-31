class Hash
  def deep_symbolize_keys
    inject({}) do |options, (key, value)|
      value = value.map { |v| v.is_a?(Hash) ? v.deep_symbolize_keys : v } if value.is_a? Array
      value = value.deep_symbolize_keys if value.is_a? Hash
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  def deep_symbolize_keys!
    self.replace(self.deep_symbolize_keys)
  end

  def deep_shellescape_values(safe_keys = [])
    inject({}) do |options, (key, value)|
      if safe_keys.include?(key)
        value
      elsif value.is_a? Array
        value = value.map { |v| v.is_a?(Hash) ? v.deep_shellescape_values(safe_keys) : v.shellescape }
      elsif value.is_a? Hash
        value = value.deep_shellescape_values(safe_keys)
      elsif value.is_a?(String) && !value.empty?
        value = value.shellescape
      end
      options[key] = value
      options
    end
  end

  def deep_shellescape_values!(safe_keys = [])
    self.replace(self.deep_shellescape_values(safe_keys))
  end

  def deep_join(separator)
  	map do |key, value|
  		case value.class.to_s
  		when 'TrueClass'
  			key
      when 'FalseClass', 'NilClass'
        nil
  		when 'Array'
  			value.map { |v| "#{key} #{v}"}
  		when 'Hash'
  			value.deep_join(separator)
      else
        "#{key} #{value}"
  		end
  	end.join(separator)
  end

  def deep_join!(separator)
  	self.replace(self.deep_join(separator))
  end
end