lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "simplerubysteps/version"

Gem::Specification.new do |spec|
  spec.name = "simplerubysteps"
  spec.version = Simplerubysteps::VERSION
  spec.authors = ["Christian Tschenett"]
  spec.email = ["simplerubysteps@furthermore.ch"]

  spec.summary = %q{simplerubysteps makes it easy to manage AWS Step Functions with ruby (this is an early alpha version and should not really be used by anyone).}

  spec.homepage = "https://github.com/chtz/simplerubysteps"
  spec.license = "MIT"

  spec.files = Dir.glob("lib/**/*.rb") + %w[exe/simplerubysteps exe/srs README.md Rakefile simplerubysteps.gemspec]

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "aws-sdk-cloudformation"
  spec.add_dependency "aws-sdk-s3"
  spec.add_dependency "aws-sdk-states"
  spec.add_dependency "aws-sdk-cloudwatchlogs"
  spec.add_dependency "rubyzip"
end
