# Create an entry in the Extension list that loads the wikihouse.rb scripts

require 'extensions.rb'

# Add all files in the lib directory to the $LOAD_PATH array
abs_lib_path = File.join(File.expand_path(File.dirname(__FILE__)), "/wikihouse-extension/lib")
$LOAD_PATH.unshift(abs_lib_path) unless $LOAD_PATH.include?(abs_lib_path)

require 'utils.rb'
require 'JSON.rb'

module WikihouseExtension

  # Run Flags
  WIKIHOUSE_DEV = true   # If true brings up Ruby Console and loads some utility functions on startup
  WIKIHOUSE_LOCAL = false 
  WIKIHOUSE_HIDE = false  
  WIKIHOUSE_SHORT_CIRCUIT = false

  # Some Global Constants
  WIKIHOUSE_TITLE = 'Wikihouse' # name of Wikihouse project, incase it changes.
  # Pannel stuff
  PANEL_ID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  PANEL_ID_ALPHABET_LENGTH = PANEL_ID_ALPHABET.length
  
  # Path setup 
  if WIKIHOUSE_LOCAL
    WIKIHOUSE_SERVER = "http://localhost:8080"
  else
    WIKIHOUSE_SERVER = "http://wikihouse-cc.appspot.com"
  end
  
  WIKIHOUSE_DOWNLOAD_PATH = "/library/sketchup"
  WIKIHOUSE_UPLOAD_PATH = "/library/designs/add/sketchup"
  WIKIHOUSE_DOWNLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_DOWNLOAD_PATH
  WIKIHOUSE_UPLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_UPLOAD_PATH
  
  WIKIHOUSE_TEMP = get_temp_directory
  
  # Get Platform
  if RUBY_PLATFORM =~ /mswin/
    WIKIHOUSE_CONF_FILE = File.join ENV['APPDATA'], 'WikiHouse.conf'
    WIKIHOUSE_SAVE = get_documents_directory ENV['USERPROFILE'], 'Documents'
    WIKIHOUSE_MAC = false
  else
    WIKIHOUSE_CONF_FILE = File.join ENV['HOME'], '.wikihouse.conf'
    WIKIHOUSE_SAVE = get_documents_directory ENV['HOME'], 'Documents'
    WIKIHOUSE_MAC = true
  end
  
  # Set defaults for Global Variables 
  
  # Set Wikihouse Pannel Dimentions
  wikihouse_sheet_height = 1200.mm
  wikihouse_sheet_width = 2400.mm
  wikihouse_sheet_depth = 18.mm
  wihihouse_panel_padding = 25.mm / 2
  wikihouse_sheet_margin = 15.mm - wihihouse_panel_padding
  wikihouse_font_height = 30.mm
  wikihouse_sheet_inner_height = wikihouse_sheet_height - (2 * wikihouse_sheet_margin)
  wikihouse_sheet_inner_width = wikihouse_sheet_width - (2 * wikihouse_sheet_margin)
  
  #(Chris) Plan to eventually store all setting as a hash. 
  
  # Store the actual values as length objects (in inches)
  $wikihouse_settings = {
  "sheet_height" => wikihouse_sheet_height,
  "sheet_inner_height" => wikihouse_sheet_inner_height,
  "sheet_width"  => wikihouse_sheet_width, 
  "sheet_inner_width"  => wikihouse_sheet_inner_width,
  "sheet_depth" => wikihouse_sheet_depth, 
  "padding"      => wihihouse_panel_padding,
  "margin"       => wikihouse_sheet_margin,
  "font_height"  => wikihouse_font_height,
  }
  
  # Store default values for recall
  DEFAULT_SETTINGS = Hash[$wikihouse_settings]
  
# NEEDED IF SETTINGS IS A MODULE/CLASS VARIABLE (currently made it global)
#   Note: module variable @@wikihouse_settings is accessable in WikihouseExtension namespace
#   e.g. X = @@wikihouse_settings["sheet_height"] but not in any subclasses. 
#   Therefore use get methods so they can be returned via referencing the module 
#      e.g. settings = WikihouseExtension.settings
#      e.g. X = settings["sheet_height"]
#   Or all at once: 
#      e.g. X = WikihouseExtension.settings["sheet_height"].
#  def self.settings
#    $wikihouse_settings
#  end
#  def self.settings=(settings)
#    $wikihouse_settings = settings
#  end
  
  # Define and Load the wikihouse Extension 
  WIKIHOUSE_EXTENSION = SketchupExtension.new "Wikihouse Plugin Development Version", "wikihouse-extension/wikihouse.rb"
  WIKIHOUSE_EXTENSION.version = ' 0.2 Dev'
  WIKIHOUSE_EXTENSION.description = "Allows for the sharing and downloading of wikihouse models at http://www.wikihouse.cc/, as well as the traslation of models to cutting templates."
  WIKIHOUSE_EXTENSION.creator = " Wikihouse Development Team"
  WIKIHOUSE_EXTENSION.copyright = " Public Domain - 2013"
  
  # All constants should be defined before loading extension to avoid error. 
  Sketchup.register_extension WIKIHOUSE_EXTENSION, true

end
