# Wikihouse Extension 0.2 Dev

This is the WikiHouse extension for use Google SketchUp designed for the [Wikihouse](http://www.wikihouse.cc/) open source construction set. Using it,  
you can:

* Import designs from the WikiHouse library.

* Share your designs easily through the WikiHouse library.

* Generate cutting sheets for your house designs.

See the [changes log](changes.md) for a list of recent changes and new features. 

**Current Version: 0.2 Dev** 

##Installing

###Using the Make File
  
1.  Download or clone the repository, then run `make build` to generate the `wikihouse_extension.rbz` file.
2.  Open SketchUp and navigate to **Window** > **Preferences** (Microsoft Windows) or **SketchUp** > **Preferences** (Mac OS X).
3.  Click on Extensions, which will display all current extensions installed. 
4.  Click on the *Install Extension* button and locate the built `wikihouse_extension.rbz` file to install it.

The plugin will then appear in the list of other extensions, and all necessary files will be copied to your plugins directory. If you ever wish to disable it, simply untick it in the list and restart SketchUp. 

###Manually

With the "Plugins" folder for SketchUp being by default:

*  `C:\Program Files\Google\Google SketchUp 8\Plugins` On Windows.
*  `/Library/Application Support/Google SketchUp 8/SketchUp/Plugins` On Mac.

Download or clone repository and manually move the `wikihouse_extension_loader.rb` file
as well as the `wikihouse-extension` folder plus all contents to the "Plugins" folder for SketchUp.

Installation on previous versions of SketchUp (version 7 and bellow) has to be done the manual way. 

##License

All of the code has been released into the [Public Domain]. Do with it  
as you please.

[Public Domain]: https://github.com/tav/wikihouse-plugin/raw/master/UNLICENSE
