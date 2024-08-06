all: tohray

tohray: *.nim
	nim -d:debug c tohray.nim

.PHONY:
clean:
	rm -f tohray
