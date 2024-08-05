all: tohray

initdb: initdb.nim
	nim -d:debug compile $<

tohray: *.nim
	nim -d:debug compile tohray.nim 

.PHONY:
clean:
	rm -f app
	rm -f initdb
