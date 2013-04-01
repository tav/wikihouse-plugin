# Create an entry in the Extension list that loads the wikihouse.rb scripts

require 'extensions.rb'

# Add all files in the lib directory to the $LOAD_PATH array
abs_lib_path = File.join(File.expand_path(File.dirname(__FILE__)), "/wikihouse-extension/lib")
$LOAD_PATH.unshift(abs_lib_path) unless $LOAD_PATH.include?(abs_lib_path)

require 'utils.rb'

module WikihouseExtension

  # Run Flags
  WIKIHOUSE_DEV = true
  WIKIHOUSE_LOCAL = false
  WIKIHOUSE_HIDE = false
  WIKIHOUSE_SHORT_CIRCUIT = false

  # Some Global Constants
  WIKIHOUSE_TITLE = 'Wikihouse' # name of Wikihouse project, incase it changes.
  
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
  
  # Define and Load the wikihouse Extension 
  WIKIHOUSE_EXTENSION = SketchupExtension.new "Wikihouse Plugin Development Version", "wikihouse-extension/wikihouse.rb"
  WIKIHOUSE_EXTENSION.version = ' 0.1'
  WIKIHOUSE_EXTENSION.description = "Allows for the sharing and downloading of wikihouse models at http://www.wikihouse.cc/, as well as the traslation of models to cutting templates."
  WIKIHOUSE_EXTENSION.creator = " Wikihouse Development Team"
  WIKIHOUSE_EXTENSION.copyright = " Public Domain - 2013"
  
  # All constants should be defined before loading extension to avoid error. 
  Sketchup.register_extension WIKIHOUSE_EXTENSION, true

end
