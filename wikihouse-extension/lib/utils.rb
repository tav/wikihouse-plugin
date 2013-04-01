
module WikihouseExtension

  # ------------------------------------------------------------------------------
  # Utility Functions
  # ------------------------------------------------------------------------------
     
  # Path Utilities
  def get_documents_directory(home, docs)
    dir = File.join home, docs
    if not (File.directory?(dir) and File.writable?(dir))
      home
    else
      dir
    end
  end

  def get_temp_directory
    temp = '.'
    for dir in [ENV['TMPDIR'], ENV['TMP'], ENV['TEMP'], ENV['USERPROFILE'], '/tmp']
    if dir and File.directory?(dir) and File.writable?(dir)
      temp = dir
      break
    end
    end
    File.expand_path temp
  end
  
 
  # Status Messages
  def gen_status_msg(msg)
    return [
      msg + " .",
      msg + " ..",
      msg + " ...",
      msg + " ....",
      msg + " .....",
    ]
  end
  
  
  def get_wikihouse_thumbnail(model, view, suffix)
    filename = File.join WIKIHOUSE_TEMP, "#{model.guid}-#{suffix}.png"
    opts = {
      :antialias => true,
      :compression => 0.8,
      :filename => filename,
      :height => [view.vpheight, 1600].min,
      :transparent => true,
      :width => [view.vpwidth, 1600].min
    }
    view.write_image opts
    data = File.open(filename, 'rb') do |io|
      io.read
    end
    File.delete filename
    data
  end
  
  def get_dom_value(dialog, id, value)
    if value.length > 2097152
      dialog.execute_script "WIKIHOUSE_DATA = [#{value[0...2097152].inspect}];"
      start, stop = 2097152, (2097152+2097152)
      idx = 1
      while 1
        segment = value[start...stop]
        if not segment
          break
        end
        dialog.execute_script "WIKIHOUSE_DATA[#{idx}] = #{segment.inspect};"
        idx += 1
        start = stop
        stop = stop + 2097152
      end
      dialog.execute_script "document.getElementById('#{id}').value = WIKIHOUSE_DATA.join('');"
    else
      dialog.execute_script "document.getElementById('#{id}').value = #{value.inspect};"
    end
  end
  
  def show_wikihouse_error(msg)
    UI.messagebox "!! ERROR !!\n\n#{msg}"
  end
  
  extend self
  # Adds all instance methods previously defined here in a 'WikihouseExtension' namespace to  
  # the module itself, therfore allowing access to instance methods without the need to make a class first.

  # ------------------------------------------------------------------------------
  # Utility Classes
  # ------------------------------------------------------------------------------
 
  # App Observer
  # ------------------------------------------------------------------------------
  class WikiHouseAppObserver < Sketchup::AppObserver
    
    def onNewModel(model)
    end
  
    # TODO(tav): This doesn't seem to be getting called.
    # (Chris) Should do now I think. Still need to test.
    def onQuit
      if WIKIHOUSE_DOWNLOADS.length > 0
        show_wikihouse_error "Aborting downloads from #{WIKIHOUSE_TITLE}"
      end
      if WIKIHOUSE_UPLOADS.length > 0
        show_wikihouse_error "Aborting uploads to #{WIKIHOUSE_TITLE}"
      end
    end 
  end

  # Load Handler
  # ------------------------------------------------------------------------------
  # (Chris) For loading Wikihouse models via web?
  
  class WikiHouseLoader
  
    attr_accessor :cancel, :error
  
    def initialize(name)
      @cancel = false
      @error = nil
      @name = name
    end
  
    def cancelled?
      @cancel
    end
  
    def onFailure(error)
      @error = error
      Sketchup.set_status_text ''
    end
  
    def onPercentChange(p)
      Sketchup.set_status_text "LOADING #{name}:    #{p.to_i}%"
    end
  
    def onSuccess
      Sketchup.set_status_text ''
    end
  
  end

  
end
