**Wikihouse Extension 0.2 Dev**

New Features:

*  Wikihouse now loadable as a Sketchup Extension.
*  Settings Menu added to custimise sheet dimentions. 

List of Changes: 
 
*    Split the main Wikihouse.rb file into multiple files of related code located in the `wikihouse_extension/lib/` directory.
*    Wrapped the whole code into a Ruby module called `WikihouseExtension`, thereby protecting against any namespace clashes in the future.
*    `wikihouse_extension_loader.rb` script now contains all the configuration constants such as paths, platform, and run flags which are most likely to be changed between runs.
*    All utility functions are now in the file `utils.rb` along with any other perminant constants. 
*    All output writer classes moved to a file called `writers.rb`.
*    All WebDialoge moved to  `WebDialog.rb`.
*    Added a hash **$wikihouse_settings** as a global variale to store all variable configureation/settup data.
*    Any code that is not currently functional is in `other.rb`. 
*    Added methods to convert Ruby Hash and Array classes to JSON strings and vice versa. This provides a more flexible bridge between Ruby and JavaScript in the Web Dialogues.
*    Added this change log file.
