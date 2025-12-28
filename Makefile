all: tohray

tohray: *.nim
	nim -d:debug -d:nimcryptoAvx2=false c tohray.nim

release: *.nim
	nim -d:release -d:nimcryptoAvx2=false c tohray.nim

.PHONY: clean
clean:
	rm -f tohray
