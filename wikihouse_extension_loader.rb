# Create an entry in the Extension list that loads the wikihouse.rb scripts

require 'sketchup.rb'
require 'extensions.rb'

wikihouse_extension = SketchupExtension.new "Wikihouse Plugin", "wikihouse-plugin/wikihouse.rb"
wikihouse_extension.version = '0.1'
wikihouse_extension.description = "Allows for the sharing and downloading of wikihouse models at http://www.wikihouse.cc/, as well as the trasformation of models to cutting templates."
wikihouse_extension.creator = "Wikihouse Development Team"
wikihouse_extension.copyright = "Public Domain - 2013"

Sketchup.register_extension wikihouse_extension, true