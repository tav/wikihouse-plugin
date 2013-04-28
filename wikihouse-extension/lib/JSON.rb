# JSON formatter for parsing Ruby hases and Arrays to JavaScript as
# json objects.
#
# Original Author: Aerilius
# Source: http://sketchucation.com/forums/viewtopic.php?f=180&t=35969
#

module WikihouseExtension
  
  module JSON
  
    module_function() # Allows Methods to be callable from module 
    
    def from_json(json_string)
      # split at every even number of unescaped quotes; if it's not a string then replace : and null
      ruby_string = json_string.split(/(\"(?:.*?[^\\])*?\")/).
        collect{|s|
          (s[0..0] != '"')? s.gsub(/\:/, "=>").gsub(/null/, "nil") : s
        }.
        join()
      result = eval(ruby_string)
      return result
    rescue Exception => e
      {}
    end
  
    def to_json(obj)
      json_classes = [String, Symbol, Fixnum, Float, Length, Array, Hash, TrueClass, FalseClass, NilClass]
      # remove non-JSON objects
      check_value = nil
      check_array = Proc.new{|o| o.reject!{|k| !check_value.call(k) } }
      check_hash = Proc.new{|o| o.reject!{|k,v| !k.is_a?(String) && !k.is_a?(Symbol) || !check_value.call(v) } }
      check_value = Proc.new{|v|
        if v.is_a?(Array)
          check_array.call(v)
        elsif v.is_a?(Hash)
          check_hash.call(v)
        end
        json_classes.include?(v.class)
      }
      return "null" unless check_value.call(obj)
      # split at every even number of unescaped quotes; if it's not a string then turn Symbols into String and replace => and nil
      json_string = obj.inspect.split(/(\"(?:.*?[^\\])*?\")/).collect{ |s|
          (s[0..0] != '"')?                        # If we are not inside a string
          s.gsub(/\:(\S+?(?=\=>|\s))/, "\"\\1\""). # Symbols to String
            gsub(/=>/, ":").                       # Arrow to colon
            gsub(/\bnil\b/, "null") :              # nil to null
          s
        }.join()
      return json_string
    end
    
  end #JSON

end # Wikihouse Module