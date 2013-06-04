OUTPUT = bin/another.swf

FILES = src/*.as src/*/* src/*/*/* src/*/*/*/* Makefile

FLAGS = --target-player=10.0.0 -compiler.optimize  -compiler.library-path+=src  \
		-default-size 640 400 -default-frame-rate 60 -default-background-color 0

all: $(OUTPUT)

clean:
	rm -Rf $(OUTPUT)

run: $(OUTPUT)
	open $<

bin/another.swf: $(FILES)
	mxmlc $(FLAGS) -output $@ src/Main.as
	
.PHONY: all
