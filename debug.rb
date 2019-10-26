require './lib/tess_scrapers'

options = { debug: true, verbose: true, offline: true, cache: true }

ARGV[0].constantize.new(options).run
