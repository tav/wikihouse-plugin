Wikihouse 0.2 Dev:

List of Changes 
	⁃	Wikihouse now loadable as a Sketchup Extension.
	⁃	Split the main Wikihouse.rb file into multiple files of related code located in the `wikihouse_extension/lib/` directory.
	⁃	Wrapped the whole code into a Ruby module called `WikihouseExtension`, thereby protecting against any namespace clashes in the future.
	⁃	`wikihouse_extension_loader.rb` script now contains all the configuration constants such as paths, platform, and run flags which are most likely to be changed between runs.
	⁃	All utility functions are now in the file 'utils.rb' along with any other perminant constants. 
	⁃	All output writer classes moved to a file called 'writers.rb'


All WebDialoge moved to  'WebDialogue.rb'