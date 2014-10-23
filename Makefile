PANDOC=pandoc
BASE_CSS=normalize.css
CUSTOM_CSS=tutorial.css
SOURCES=index.html judgement2.html judgement3.html

all: $(SOURCES)

%.html: %.md
	$(PANDOC) $< -o $@ -c $(BASE_CSS) -c $(CUSTOM_CSS)
