
ArgumentToolsError = Class.new(StandardError);

module ArgumentTools
  
  def assign_arguments(definitions, variables)
    variables.each do |variable|
      self.send("#{variable}=", definitions[variable] || nil)
    end
  end
  
  def ensure_exists!(args)
    args.each do |arg|
      unless self.send("#{arg}")
        raise ArgumentToolsError, "Required argument #{arg} is not defined for #{self}."
      end
    end
  end
  
end