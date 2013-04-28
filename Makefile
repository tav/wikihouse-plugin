# Make file for creating wikihouse_extention.rbz 

assets=wikihouse-extension/wikihouse-assets/*
libs=wikihouse-extension/lib/*

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
	
install_mac: wikihouse_extension_loader.rb wikihouse-extension/wikihouse.rb $(assets) $(libs)
	# Copying files to their locations 
	cp -v wikihouse_extension_loader.rb /Library/Application\ Support/Google\ SketchUp\ 8/SketchUp/plugins/wikihouse_extension_loader.rb
	cp -v wikihouse-extension/wikihouse.rb /Library/Application\ Support/Google\ SketchUp\ 8/SketchUp/plugins/wikihouse-extension/wikihouse.rb
	cp -v $(assets) /Library/Application\ Support/Google\ SketchUp\ 8/SketchUp/plugins/wikihouse-extension/wikihouse-assets/
	cp -v $(libs) /Library/Application\ Support/Google\ SketchUp\ 8/SketchUp/plugins/wikihouse-extension/lib/