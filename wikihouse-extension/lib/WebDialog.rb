# Web Dialogues

module WikihouseExtension

  module_function() # Makes all methods defined in the module callable via
  #ModuleName.method. Else would have to define a class and mix them into it first.

  # ------------------------------------------------------------------------------
  # Common Callbacks
  # ------------------------------------------------------------------------------
  
  # Download Callback
  # -----------------
  def wikihouse_download_callback(dialog, params)
    # Exit if the download parameters weren't set.
    if params == ""
      show_wikihouse_error "Couldn't find the #{WIKIHOUSE_TITLE} model name and url"
      return
    end

    is_comp, base64_url, blob_url, name = params.split ",", 4
    model = Sketchup.active_model

    # Try and save the model/component directly into the current model.
    if model and is_comp == '1'
      reply = UI.messagebox "Load this directly into your Google SketchUp model?", MB_YESNOCANCEL
      if reply == REPLY_YES
        loader = WikiHouseLoader.new name
        blob_url = WIKIHOUSE_SERVER + blob_url
        model.definitions.load_from_url blob_url, loader
        if not loader.error
          dialog.close
          UI.messagebox "Successfully downloaded #{name}"
          component = model.definitions[-1]
          if component
            model.place_component component
          end
          return
        else
          UI.messagebox loader.error
          reply = UI.messagebox "Would you like to save the model file instead?", MB_YESNO
          if reply == REPLY_NO
            return
          end
        end
      elsif reply == REPLY_NO
        # Skip through to saving the file directly.
      else
        return
      end
    end

    # Otherwise, get the filename to save into.
    filename = UI.savepanel "Save Model", WIKIHOUSE_SAVE, "#{name}.skp"
    if not filename
      show_wikihouse_error "No filename specified to save the #{WIKIHOUSE_TITLE} model. Please try again."
      return
    end

    # TODO(tav): Ensure that this is atomic and free of thread-related
    # concurrency issues.
    $WIKIHOUSE_DOWNLOADS_ID += 1
    download_id = $WIKIHOUSE_DOWNLOADS_ID.to_s

    WIKIHOUSE_DOWNLOADS[download_id] = filename
    
    # Initiate the download.
    dialog.execute_script "wikihouse.download('#{download_id}', '#{base64_url}');"
  end

  # Save Callback
  # -------------
  def wikihouse_save_callback(dialog, download_id)
    errmsg = "Couldn't find the #{WIKIHOUSE_TITLE} model data to save"

    # Exit if the save parameters weren't set.
    if download_id == ""
      show_wikihouse_error errmsg
      return
    end

    if not WIKIHOUSE_DOWNLOADS.key? download_id
      show_wikihouse_error errmsg
      return
    end

    filename = WIKIHOUSE_DOWNLOADS[download_id]
    WIKIHOUSE_DOWNLOADS.delete download_id

    
    # TODO:(Chris) The Wikihouse Model Loading currently fails here as the  
    # segment_count value returned is the empty string ""
    segment_count = dialog.get_element_value "design-download-data"
    
    dialog.close

    if segment_count == ""
      show_wikihouse_error errmsg
      puts "Segment count variable was not parsed correctly"
      return
    end

    data = []
    for i in 0...segment_count.to_i
      segment = dialog.get_element_value "design-download-data-#{i}"
      if segment == ""
        show_wikihouse_error errmsg
        return
      end
      data << segment
    end

    # Decode the base64-encoded data.
    data = data.join('').unpack("m")[0]
    if data == ""
      show_wikihouse_error errmsg
      puts "Triger 5"
      return
    end

    # Save the data to the local file.
    File.open(filename, 'wb') do |io|
      io.write data
    end

    reply = UI.messagebox "Successfully saved #{WIKIHOUSE_TITLE} model. Would you like to open it?", MB_YESNO
    if reply == REPLY_YES
      if not Sketchup.open_file filename
        show_wikihouse_error "Couldn't open #{filename}"
      end
    end
  end

  # Error Callback
  # --------------
  def wikihouse_error_callback(dialog, download_id)
    if not WIKIHOUSE_DOWNLOADS.key? download_id
      return
    end

    filename = WIKIHOUSE_DOWNLOADS[download_id]
    WIKIHOUSE_DOWNLOADS.delete download_id

    show_wikihouse_error "Couldn't download #{filename} from #{WIKIHOUSE_TITLE}. Please try again."
  end

  # ------------------------------------------------------------------------------
  # Download Web Dialogue
  # ------------------------------------------------------------------------------
  def load_wikihouse_download

    # Exit if the computer is not online.
    if not Sketchup.is_online
      UI.messagebox "You need to be connected to the internet to download #{WIKIHOUSE_TITLE} models."
      return
    end

    dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, "#{WIKIHOUSE_TITLE}-Download", 480, 640, 150, 150, true

    dialog.add_action_callback("download") { |dialog, params|
      wikihouse_download_callback(dialog, params)
    }

    dialog.add_action_callback("save") { |dialog, download_id|
      
      puts download_id
      
      wikihouse_save_callback(dialog, download_id)
    }

    dialog.add_action_callback("error") { |dialog, download_id|
      wikihouse_error_callback(dialog, download_id)
    }

    # Set the dialog's url and display it.
    dialog.set_url WIKIHOUSE_DOWNLOAD_URL
    dialog.show
    dialog.show_modal

  end

  # ------------------------------------------------------------------------------
  # Upload Web Dialogue
  # ------------------------------------------------------------------------------

  def load_wikihouse_upload

    # Exit if the computer is not online.
    if not Sketchup.is_online
      UI.messagebox "You need to be connected to the internet to upload models to #{WIKIHOUSE_TITLE}."
      return
    end

    model = Sketchup.active_model

    # Exit if a model wasn't available.
    if not model
      show_wikihouse_error "You need to open a SketchUp model to share"
      return
    end

    # Initialise an attribute dictionary for custom metadata.
    attr = model.attribute_dictionary WIKIHOUSE_TITLE, true
    if attr.size == 0
      attr["spec"] = "0.1"
    end

    # Exit if it's an unsaved model.
    model_path = model.path
    if model_path == ""
      UI.messagebox "You need to save the model before it can be shared at #{WIKIHOUSE_TITLE}"
      return
    end

    # Auto-save the model if it has been modified.
    if model.modified?
      if not model.save model_path
        show_wikihouse_error "Couldn't auto-save the model to #{model_path}"
        return
      end
    end

    # Try and infer the model's name.
    model_name = model.name
    if model_name == ""
      model_name = model.title
    end

    # Instantiate an upload web dialog.
    dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, "#{WIKIHOUSE_TITLE}-Upload", 480, 640, 150, 150, true

    # Load Callback
    # -------------
    # Load default values into the upload form.
    dialog.add_action_callback("load") { |dialog, params|
      if model_name != ""
        if dialog.get_element_value("design-title") == ""
          set_dom_value dialog, "design-title", model_name
        end
      end
      if model.description != ""
        if dialog.get_element_value("design-description") == ""
          set_dom_value dialog, "design-description", model.description
        end
      end
      if Sketchup.version
        set_dom_value dialog, "design-sketchup-version", Sketchup.version
      end
      set_dom_value dialog, "design-plugin-version", WIKIHOUSE_PLUGIN_VERSION
    }

    # Process Callback
    # --------------
    # Process and prepare the model related data for upload.
    dialog.add_action_callback("process") { |dialog, params|

      if File.size(model_path) > 12582912
        reply = UI.messagebox "The model file is larger than 12MB. Would you like to purge unused objects, materials and styles?", MB_OKCANCEL
        if reply == REPLY_OK
          model.layers.purge_unused
          model.styles.purge_unused
          model.materials.purge_unused
          model.definitions.purge_unused
          if not model.save model_path
            show_wikihouse_error "Couldn't save the purged model to #{model_path}"
            dialog.close
            return
          end
          if File.size(model_path) > 12582912
            UI.messagebox "The model file is still larger than 12MB after purging. Please break up the file into smaller components."
            dialog.close
            return
          end
        else
          dialog.close
        end
      end

      # Get the model file data.
      model_data = File.open(model_path, 'rb') do |io|
        io.read
      end

      model_data = [model_data].pack('m')
      set_dom_value dialog, "design-model", model_data

      # Capture the current view info.
      view = model.active_view
      camera = view.camera
      eye, target, up = camera.eye, camera.target, camera.up
      center = model.bounds.center

      # Get the data for the model's front image.
      front_thumbnail = get_wikihouse_thumbnail model, view, "front"
      if not front_thumbnail
        show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
        dialog.close
        return
      end

      front_thumbnail = [front_thumbnail].pack('m')
      set_dom_value dialog, "design-model-preview", front_thumbnail

      # Rotate the camera and zoom all the way out.
      rotate = Geom::Transformation.rotation center, Z_AXIS, 180.degrees
      camera.set eye.transform(rotate), center, Z_AXIS
      view.zoom_extents

      # Get the data for the model's back image.
      back_thumbnail = get_wikihouse_thumbnail model, view, "back"
      if not back_thumbnail
        camera.set eye, target, up
        show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
        dialog.close
        return
      end

      back_thumbnail = [back_thumbnail].pack('m')
      set_dom_value dialog, "design-model-preview-reverse", back_thumbnail

      # Set the camera view back to the original setup.
      camera.set eye, target, up

      # Get the generated sheets data.
      sheets_data = make_wikihouse model, false
      if not sheets_data
        svg_data, dxf_data = "", ""
      else
        svg_data = [sheets_data[0]].pack('m')
        dxf_data = [sheets_data[1]].pack('m')
      end

      set_dom_value dialog, "design-sheets", dxf_data
      set_dom_value dialog, "design-sheets-preview", svg_data

      WIKIHOUSE_UPLOADS[dialog] = 1
      dialog.execute_script "wikihouse.upload();"
    }

    # Uploaded Callback
    # -----------------
    dialog.add_action_callback "uploaded" do |dialog, params|
      if WIKIHOUSE_UPLOADS.key? dialog
        WIKIHOUSE_UPLOADS.delete dialog
      end
      if params == "success"
        UI.messagebox "Successfully uploaded #{model_name}"
      else
        UI.messagebox "Upload to #{WIKIHOUSE_TITLE} failed. Please try again."
      end
    end

    dialog.add_action_callback "download" do |dialog, params|
      wikihouse_download_callback dialog, params
    end

    dialog.add_action_callback "save" do |dialog, download_id|
      wikihouse_save_callback dialog, download_id
    end

    dialog.add_action_callback "error" do |dialog, download_id|
      wikihouse_error_callback dialog, download_id
    end

    # TODO(tav): There can be a situation where the dialog has been closed, but
    # the upload succeeds and the dialog gets called with "uploaded" and brought
    # to front.
    dialog.set_on_close do
      dialog.set_url "about:blank"
      if WIKIHOUSE_UPLOADS.key? dialog
        show_wikihouse_error "Upload to #{WIKIHOUSE_TITLE} has been aborted"
        WIKIHOUSE_UPLOADS.delete dialog
      end
    end

    dialog.set_url WIKIHOUSE_UPLOAD_URL
    dialog.show
    dialog.show_modal

  end

  # ------------------------------------------------------------------------------
  # Make Web Dialog
  # ------------------------------------------------------------------------------

  def load_wikihouse_make
  
    model = Sketchup.active_model
  
    # Exit if a model wasn't available.
    if not model
      show_wikihouse_error "You need to open a SketchUp model before it can be fabricated"
      return
    end
    
    # Initialise an attribute dictionary for custom metadata.
    attr = model.attribute_dictionary WIKIHOUSE_TITLE, true
    if attr.size == 0
      attr["spec"] = WIKIHOUSE_EXTENSION.version
    end
  
    # Exit if it's an unsaved model.
    model_path = model.path
    if model_path == ""
      UI.messagebox "You need to save the model before the cutting sheets can be generated"
      return
    end
  
    # Try and infer the model's filename.
    filename = model.title
    if filename == ""
      filename = "Untitled"
    end
  
    # Get the model's parent directory and generate the new filenames to save to.
    directory = File.dirname(model_path)
    svg_filename = File.join(directory, filename + ".svg")
    dxf_filename = File.join(directory, filename + ".dxf")
  
    # Make the cutting sheets for the house!
    data = make_wikihouse model, true
    if not data
      return
    end
  
    svg_data, dxf_data = data
  
    # Save the SVG data to the file.
    File.open(svg_filename, "wb") do |io|
      io.write svg_data
    end
  
    # Save the DXF data to the file.
    File.open(dxf_filename, "wb") do |io|
      io.write dxf_data
    end
  
    UI.messagebox "Cutting sheets successfully saved to #{directory}", MB_OK
  
    if WIKIHOUSE_MAC
      dialog = UI::WebDialog.new "Cutting Sheets Preview", true, "#{WIKIHOUSE_TITLE}-Preview", 800, 800, 150, 150, true
      dialog.set_file svg_filename
      dialog.show
      dialog.show_modal
    end
  
  end
  
  # ------------------------------------------------------------------------------
  # Settings Web Dialogue
  # ------------------------------------------------------------------------------

  def load_wikihouse_settings

    # Create WebDialog
    dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, "#{WIKIHOUSE_TITLE}-Settings", 480, 660, 150, 150, true

    # Get Current Wikihouse Settings
    dialog.add_action_callback("fetch_settings") { |d, args|

      if args == "default"

        # Convert Dimenstions to mm
        dims = {}
        for k, v in DEFAULT_SETTINGS do
          dims[k] = v.to_mm
        end
        script = "recieve_wikihouse_settings('" + JSON.to_json(dims) + "');"
        d.execute_script(script)

      elsif args == "current"

        # Convert Dimenstions to mm
        dims = {}
        for k, v in $wikihouse_settings do
          dims[k] = v.to_mm
        end
        script = "recieve_wikihouse_settings('" + JSON.to_json(dims) + "');"
        d.execute_script(script)
      end
    }

    # Set Web Dialog's Callbacks
    dialog.add_action_callback("update_settings") { |d, args|

      close_flag = false
      if args.include? "--close"
        close_flag = true
        args = args.gsub("--close", "")
      end

      #      UI.messagebox("Passed Arguments = #{args}")

      new_settings = JSON.from_json(args)

      for k,v in new_settings do
        # Convert mm back to inches
        $wikihouse_settings[k] = v.mm
      end

      # Recalculate inner heights and widths
      $wikihouse_settings["sheet_inner_height"] = $wikihouse_settings["sheet_height"] - (2 * $wikihouse_settings["margin"])
      $wikihouse_settings["sheet_inner_width"] = $wikihouse_settings["sheet_width"] - (2 * $wikihouse_settings["margin"])

      puts "Dimensions Updated!"

      if close_flag == true
        d.close
      else
        d.execute_script("display_status('" + "Settings Updated!" + "');")
      end
    }

    # Cancel and close dialog
    dialog.add_action_callback("cancel_settings") { |d, args|
      d.close }

    # Set HTML
    html_path = Sketchup.find_support_file "settings.html", "Plugins/wikihouse-extension/lib/"
    dialog.set_file html_path
    dialog.show_modal
    #    dialog.bring_to_front
    #    dialog.show

    puts "Dialog Loaded"

  end

end