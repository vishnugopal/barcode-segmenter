

module Debuggable
  
  attr_accessor :debug_mode
  
  def out(message)
    puts "#{Time.now}: #{message}" if debug_mode
  end
  
  def debug_mode?
    debug_mode == true
  end
  
end