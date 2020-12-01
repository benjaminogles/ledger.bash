
AWK_OUT = $(patsubst %.in, %, $(wildcard *.awk.in))

.PHONY: clean all

all: $(AWK_OUT)

%.awk: %.awk.in utils.awk
	cat $^ > $@

clean:
	$(RM) $(AWK_OUT)

