setup:
	find . -type f -maxdepth 1 | xargs chmod 644
	find . -type d -maxdepth 1 | xargs chmod 755
	chmod 757 xml csv stats daily # so that user `www` can write/delete files
	chmod 757 `pwd`
	# Meaningless to set permission to symbolic link

upload:
	rsync -avz `pwd` 133.1.141.121:~/Sites/ --exclude ".DS_Store"

download:
	rsync -avz  133.1.141.121:~/Sites/comet_cdc/ ./

clean:
	rm -f *~  */*~ .*swp */.*swp
