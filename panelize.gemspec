# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'panelize/version'

Gem::Specification.new do |gem|
  gem.name          = "panelize"
  gem.version       = Panelize::VERSION
  gem.authors       = ["Colin J. Fuller"]
  gem.email         = ["cjfuller@gmail.com"]
  gem.description   = %q{Script for arranging microscopy images into a grid with constant leveling for making figures.}
  gem.summary       = %q{Script for arranging microscopy images into a grid with constant leveling for making figures.  Multiple channels are supported with up to three-channel merge.  An arbitrary number of treatments is supported; each channel is scaled the same across all treatments.  Adds a scalebar to the lower left image in the grid.}
  gem.homepage      = "https://github.com/cjfuller/panelize"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency('rimageanalysistools', '>= 5.1.4.2')
  gem.add_dependency('trollop')
  gem.add_dependency('highline')

  gem.platform = 'java'
  gem.requirements = 'jruby'
end
