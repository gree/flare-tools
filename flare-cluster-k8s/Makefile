all:

.PHONEY: images
images:
	docker build  -t flared:1.3.4 -f ./dockerfiles/flared .
	docker build  -t flarei:1.3.4 -f ./dockerfiles/flarei .
