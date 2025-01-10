# EMEWS tutorial

Link to GitHub IO page: https://jozik.github.io/emews_next_gen_tutorial_tests/

To build the site, simply setup asciidoctor (see below) and run:

----
$ scripts/build_site.sh
----

The site is live at https://jozik.github.io/emews_next_gen_tutorial_tests
and accessible via http://emews.org

## Developer setup

### Ubuntu

Must install asciidoctor as APT package, then asciidoctor-bibtex as Ruby Gem.

Gem does not seem to work in Anaconda, Python 3.11, 2024-02-06 .

So do all these steps:

```
$ sudo apt install ruby-dev
$ sudo apt install asciidoctor
$ sudo gem install asciidoctor-bibtex
$ sudo gem install pygments.rb
```
