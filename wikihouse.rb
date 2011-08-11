# Public Domain (-) 2011 The WikiHouse Authors.
# See the WikiHouse UNLICENSE file for details.

# =========================
# WikiHouse SketchUp Plugin
# =========================

require 'sketchup.rb'

# ------------------------------------------------------------------------------
# Path Utilities
# ------------------------------------------------------------------------------

def get_documents_directory(home, docs)
  dir = File.join(home, docs)
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
  File.expand_path(temp)
end

# ------------------------------------------------------------------------------
# Some Constants
# ------------------------------------------------------------------------------

REPLY_ABORT = 3
REPLY_CANCEL = 2
REPLY_NO = 7
REPLY_OK = 1
REPLY_RETRY = 4
REPLY_YES = 6

if RUBY_PLATFORM =~ /mswin/
  WIKIHOUSE_CONF_FILE = File.join(ENV['APPDATA'], 'WikiHouse.conf')
  WIKIHOUSE_SAVE = get_documents_directory ENV['USERPROFILE'], 'Documents'
else
  WIKIHOUSE_CONF_FILE = File.join(ENV['HOME'], '.wikihouse.conf')
  WIKIHOUSE_SAVE = get_documents_directory ENV['HOME'], 'Documents'
end

WIKIHOUSE_DEV = false

if WIKIHOUSE_DEV
  WIKIHOUSE_SERVER = "http://localhost:8080"
else
  WIKIHOUSE_SERVER = "https://wikihouse-cc.appspot.com"
end

WIKIHOUSE_DOWNLOAD_PATH = "/library"
WIKIHOUSE_UPLOAD_PATH = "/library/add_design"
WIKIHOUSE_DOWNLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_DOWNLOAD_PATH
WIKIHOUSE_UPLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_UPLOAD_PATH

WIKIHOUSE_TEMP = get_temp_directory
WIKIHOUSE_TITLE = "WikiHouse"

# ------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------

def get_wikihouse_thumbnail(model, view, suffix)
  filename = File.join(WIKIHOUSE_TEMP, "#{model.guid}-#{suffix}.png")
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

def set_dom_value(dialog, id, value)
  # value.gsub! "'", "\\\\'"
  # value.gsub! "\n", " "
  dialog.execute_script "document.getElementById('#{id}').value = #{value.inspect};"
end

def show_wikihouse_error(msg)
  UI.messagebox "!! ERROR !!\n\n#{msg}"
end

# ------------------------------------------------------------------------------
# Load Handler
# ------------------------------------------------------------------------------

class WikiHouseLoader

  attr_accessor :cancel, :error

  def initialize(name)
    @name = name
    @error = nil
    @cancel = false
  end

  def cancelled?
    @cancel
  end

  def onFailure(error)
    @error = error
    Sketchup.set_status_text('')
  end

  def onPercentChange(p)
    Sketchup.set_status_text("LOADING #{name}:    #{p.to_i}%")
  end

  def onSuccess
    Sketchup.set_status_text('')
  end

end

# ------------------------------------------------------------------------------
# App Observer
# ------------------------------------------------------------------------------

class WikiHouseAppObserver < Sketchup::AppObserver

  def onNewModel(model)
  end

  # TODO(tav): This doesn't seem to be getting called.
  def onQuit()
    if WIKIHOUSE_DOWNLOADS.length > 0
      show_wikihouse_error "Aborting downloads from #{WIKIHOUSE_TITLE}"
    end
    if WIKIHOUSE_UPLOADS.length > 0
      show_wikihouse_error "Aborting uploads to #{WIKIHOUSE_TITLE}"
    end
  end

end

# ------------------------------------------------------------------------------
# Make This House
# ------------------------------------------------------------------------------

def make_wikihouse(model)
  ""
end

# ------------------------------------------------------------------------------
# WebDialog Support
# ------------------------------------------------------------------------------

def init_wikihouse_dialog(dialog, id)
  dialog.execute_script "try { wikihouse.init('#{id}'); } catch (err) {}"
end

# ------------------------------------------------------------------------------
# Download Callbacks
# ------------------------------------------------------------------------------

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
      else
        UI.messagebox loader.error
      end
      return
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

  data = dialog.get_element_value "design-download-data"
  dialog.close

  if data == ""
    show_wikihouse_error errmsg
    return
  end

  # Decode the base64-encoded data.
  data = data.unpack("m")[0]
  if data == ""
    show_wikihouse_error errmsg
    return
  end

  # Save the data to the local file.
  File.open(filename, 'wb') do |io|
    io.write(data)
  end

  UI.messagebox "Successfully saved #{WIKIHOUSE_TITLE} model to #{filename}"

end

def wikihouse_error_callback(dialog, download_id)

  if not WIKIHOUSE_DOWNLOADS.key? download_id
    return
  end

  filename = WIKIHOUSE_DOWNLOADS[download_id]
  WIKIHOUSE_DOWNLOADS.delete download_id

  show_wikihouse_error "Couldn't download #{filename} from #{WIKIHOUSE_TITLE}. Please try again."

end

# ------------------------------------------------------------------------------
# Download Dialog
# ------------------------------------------------------------------------------

def load_wikihouse_download

  # Exit if the computer is not online.
  if not Sketchup.is_online
    UI.messagebox "You need to be connected to the internet to download #{WIKIHOUSE_TITLE} models."
    return
  end

  dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, WIKIHOUSE_TITLE, 720, 640, 150, 150, true

  dialog.add_action_callback "init" do |dialog, id|
    init_wikihouse_dialog dialog, id
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

  # Set the dialog's url and display it.
  dialog.set_url WIKIHOUSE_DOWNLOAD_URL
  dialog.bring_to_front

end

# ------------------------------------------------------------------------------
# Make Dialog
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
    attr["spec"] = "0.1"
  end

  # Exit if it's an unsaved model.
  model_path = model.path
  if model_path == ""
    UI.messagebox "You need to save the model before it can be fabricated"
    return
  end

  # Auto-save the model if it has been modified.
  if model.modified?
    if not model.save model_path
      show_wikihouse_error "Couldn't auto-save the model to #{model_path}"
      return
    end
  end

  # Try and infer the model's filename.
  filename = model.title
  if filename == ""
    filename = "Untitled"
  end

  # Get a location from the user to save the file to.
  filename = UI.savepanel "Save Fabricated Sheets", WIKIHOUSE_SAVE, filename + ".dxf"
  if not filename
    show_wikihouse_error "You need to specify a place to save the fabricated sheets. Please try again."
    return
  end

  # Make the cutting sheets for the house!
  data = make_wikihouse model
  if not data
    return
  end

  # Save the data to the file.
  File.open(filename, "wb") do |io|
    io.write(data)
  end

  UI.messagebox "Fabricated sheets successfully saved to #{filename}"

end

# ------------------------------------------------------------------------------
# Upload Dialog
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
  dialog = UI::WebDialog.new WIKIHOUSE_TITLE, true, WIKIHOUSE_TITLE, 720, 640, 150, 150, true

  # Load default values into the upload form.
  dialog.add_action_callback "load" do |dialog, params|
    if model_name != ""
      set_dom_value dialog, "design-title", model_name
    end
    if model.description != ""
      set_dom_value dialog, "design-description", model.description
    end
    if Sketchup.version
      set_dom_value dialog, "design-sketchup-version", Sketchup.version
    end
  end

  # Process and prepare the model related data for upload.
  dialog.add_action_callback "process" do |dialog, params|

    # Get the model file data.
    model_data = File.open(model_path, 'rb') do |io|
      io.read
    end

    model_data = [model_data].pack('m').tr '+/', '-_'
    set_dom_value dialog, "design-model", model_data

    # Capture the current view info.
    entities = model.entities
    view = model.active_view
    camera = view.camera
    eye, target, up = camera.eye, camera.target, camera.up
    center = model.bounds.center

    # Target the camera at the model's center.
    camera.set eye, center, Z_AXIS

    # Get the data for the model's front image.
    front_thumbnail = get_wikihouse_thumbnail model, view, "front"
    if not front_thumbnail
      show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
      dialog.close
      return
    end

    front_thumbnail = [front_thumbnail].pack('m').tr '+/', '-_'
    set_dom_value dialog, "design-model-preview", front_thumbnail

    # Rotate the camera.
    rotate = Geom::Transformation.rotation center, Z_AXIS, 180.degrees
    camera.set eye.transform(rotate), center, Z_AXIS

    # Get the data for the model's back image.
    back_thumbnail = get_wikihouse_thumbnail model, view, "back"
    if not back_thumbnail
      camera.set eye, target, up
      show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
      dialog.close
      return
    end

    back_thumbnail = [back_thumbnail].pack('m').tr '+/', '-_'
    set_dom_value dialog, "design-model-preview-reverse", back_thumbnail

    # Set the camera view back to the original setup.
    camera.set eye, target, up

    # Note: we could have also rotated the entities, e.g.
    # entities.transform_entities(rotate, entities.to_a)

    # Get the generated sheets data.
    sheets_data = [make_wikihouse(model)].pack('m').tr '+/', '-_'
    set_dom_value dialog, "design-sheets", sheets_data

    WIKIHOUSE_UPLOADS[dialog] = 1
    dialog.execute_script "wikihouse.upload();"

    # # Generate a temporary file to save the exported model.
    # filename = File.join(get_temp_directory, model.guid + ".dae")

    # # Initialise the export options.
    # export_opts = {
    #   :author_attribution  => true,
    #   :doublesided_faces   => true,
    #   :edges               => false,
    #   :materials_by_layer  => false,
    #   :preserve_instancing => true,
    #   :selectionset_only   => false,
    #   :texture_maps        => true,
    #   :triangulated_faces  => true
    # }

    # # XXX Options for hidden geometry and preserve hierarchies?

    # # Try and export the model as a COLLADA file.
    # exported = model.export filename, export_opts

    # # Again, exit if export failed.
    # if not exported
    #   show_wikihouse_error "Couldn't export the model #{model_name}"
    #   dialog.close
    #   return
    # end

  end

  dialog.add_action_callback "uploaded" do |dialog, params|
    if WIKIHOUSE_UPLOADS.key? dialog
      WIKIHOUSE_UPLOADS.delete dialog
    end
    if params == "success"
      UI.messagebox "Successfully uploaded #{model_name}"
    else
      UI.messagebox "Upload to #{WIKIHOUSE_TITLE} failed. Please try again."
    end
    dialog.bring_to_front
  end

  dialog.add_action_callback "init" do |dialog, id|
    init_wikihouse_dialog dialog, id
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

end

# ------------------------------------------------------------------------------
# Set Globals
# ------------------------------------------------------------------------------

if not file_loaded? __FILE__

  # Initialise the data containers.
  WIKIHOUSE_DOWNLOADS = Hash.new
  WIKIHOUSE_UPLOADS = Hash.new

  # Initialise the downloads counter.
  $WIKIHOUSE_DOWNLOADS_ID = 0

  # Initialise the core commands.
  WIKIHOUSE_DOWNLOAD = UI::Command.new("Get Models...") do
    load_wikihouse_download
  end

  WIKIHOUSE_DOWNLOAD.tooltip = "Find new models to use at #{WIKIHOUSE_TITLE}"

  # TODO(tav): Irregardless of this proc, all commands seem to get greyed out
  # when no models are open.
  WIKIHOUSE_DOWNLOAD.set_validation_proc {
    MF_ENABLED|MF_CHECKED
  }

  WIKIHOUSE_MAKE = UI::Command.new("Make This House...") do
    load_wikihouse_make
  end

  WIKIHOUSE_MAKE.tooltip = "Convert a model of a House into printable components"
  WIKIHOUSE_MAKE.set_validation_proc {
    if Sketchup.active_model
      MF_ENABLED|MF_CHECKED
    else
      MF_DISABLED|MF_GRAYED
    end
  }

  WIKIHOUSE_UPLOAD = UI::Command.new("Share Model...") do
    load_wikihouse_upload
  end

  WIKIHOUSE_UPLOAD.tooltip = "Upload and share your model at #{WIKIHOUSE_TITLE}"
  WIKIHOUSE_UPLOAD.set_validation_proc {
    if Sketchup.active_model
      MF_ENABLED|MF_CHECKED
    else
      MF_DISABLED|MF_GRAYED
    end
  }

  # Register a new toolbar with the commands.
  WIKIHOUSE_TOOLBAR = UI::Toolbar.new WIKIHOUSE_TITLE
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_DOWNLOAD
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_UPLOAD
  WIKIHOUSE_TOOLBAR.add_item WIKIHOUSE_MAKE
  WIKIHOUSE_TOOLBAR.show

  # Register a new submenu of the standard Plugins menu with the commands.
  WIKIHOUSE_MENU = UI.menu("Plugins").add_submenu(WIKIHOUSE_TITLE)
  WIKIHOUSE_MENU.add_item WIKIHOUSE_DOWNLOAD
  WIKIHOUSE_MENU.add_item WIKIHOUSE_UPLOAD
  WIKIHOUSE_MENU.add_item WIKIHOUSE_MAKE

  # Add our custom AppObserver.
  Sketchup.add_observer(WikiHouseAppObserver.new)

  # Display the Ruby Console in dev mode.
  if WIKIHOUSE_DEV
    Sketchup.send_action "showRubyPanel:"
    def w
      load "wikihouse.rb"
    end
    puts ""
    puts "#{WIKIHOUSE_TITLE} Plugin Successfully Loaded."
    puts ""
  end

  file_loaded __FILE__

end
