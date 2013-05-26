# Make file for creating wikihouse_extention.rbz 

assets=wikihouse-extension/wikihouse-assets/*
libs=wikihouse-extension/lib/*

plugin_dir_2013=${HOME}/Library/Application\ Support/SketchUp\ 2013/SketchUp/Plugins/
plugin_dir_SU8=/Library/Application\ Support/Google\ SketchUp\ 8/SketchUp/plugins/

# Store current git revision 
git-rev=$(git rev-parse --short=8 HEAD) 

# May need changing - not sure if full url is used for amazon buckets
wikihouse_bucket="https://wikihouse.s3.amazonaws.com/sketchup/"


build: wikihouse_extension_loader.rb $(assets) $(libs)
	# Creating .rbz file  
	zip wikihouse_extension.rbz \
	wikihouse_extension_loader.rb \
	wikihouse-extension/wikihouse.rb \
	$(assets) \
	$(libs)
	
release: wikihouse_extension.rbz
	# s3put BUCKET/[OBJECT] [FILE] - OBJECT is the name FILE is saved as in BUCKET
	s3put ${wikihouse_bucket}wikihouse_extension-$git-rev.rbz wikihouse_extension.rbz 
	s3put ${wikihouse_bucket}wikihouse_extension.rbz wikihouse_extension.rbz 
	
install_mac_SU8: wikihouse_extension_loader.rb wikihouse-extension/wikihouse.rb $(assets) $(libs)
	# Copying files to their locations 
	cp -v wikihouse_extension_loader.rb $(plugin_dir_SU8)
	cp -v wikihouse-extension/wikihouse.rb $(plugin_dir_SU8)wikihouse-extension/wikihouse.rb
	cp -v $(assets) $(plugin_dir_SU8)wikihouse-extension/wikihouse-assets/
	cp -v $(libs) $(plugin_dir_SU8)wikihouse-extension/lib/
	
install_mac_SU2013: wikihouse_extension_loader.rb wikihouse-extension/wikihouse.rb $(assets) $(libs)
	# Copying files to their locations 
	cp -v wikihouse_extension_loader.rb $(plugin_dir_2013)
	cp -v wikihouse-extension/wikihouse.rb $(plugin_dir_2013)wikihouse-extension/
	cp -v $(assets) $(plugin_dir_2013)/wikihouse-extension/wikihouse-assets/
	cp -v $(libs) $(plugin_dir_2013)/wikihouse-extension/lib/