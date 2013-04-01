# Make file for creating wikihouse_extention.rbz 

git-rev=$(git rev-parse --short=8 HEAD) 

# May need changing - not sure if full url is used for amazon buckets
wikihouse_bucket="https://wikihouse.s3.amazonaws.com/sketchup/"

build: wikihouse_extension_loader.rb $(assets) $(scripts)
	# Zip all files and subfolders recursively
	zip -r wikihouse_extension.rbz wikihouse_extension_loader.rb wikihouse-extension/*
	
release: wikihouse_extension.rbz
	# s3put BUCKET/[OBJECT] [FILE]  - OBJECT is the name FILE is saved as in BUCKET
	s3put ${wikihouse_bucket}wikihouse_extension-$git-rev.rbz wikihouse_extension.rbz 
	s3put ${wikihouse_bucket}wikihouse_extension.rbz wikihouse_extension.rbz
