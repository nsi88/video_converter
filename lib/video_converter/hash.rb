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

  def deep_shellescape_values
    inject({}) do |options, (key, value)|
      if value.is_a? Array
        value = value.map { |v| v.is_a?(Hash) ? v.deep_shellescape_values : v.shellescape }
      elsif value.is_a? Hash
        value = value.deep_shellescape_values 
      else
        value = value.to_s.shellescape
      end
      options[key] = value
      options
    end
  end

  def deep_shellescape_values!
    self.replace(self.deep_shellescape_values)
  end  
end