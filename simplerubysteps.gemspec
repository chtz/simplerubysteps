lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "simplerubysteps/version"

Gem::Specification.new do |spec|
  spec.name          = "simplerubysteps"
  spec.version       = Simplerubysteps::VERSION
  spec.authors       = ["Christian Tschenett"]
  spec.email         = ["simplerubysteps@furthermore.ch"]

  spec.summary       = %q{simplerubysteps makes it easy to manage AWS Step Functions with ruby (eventually - this is an early alpha version and should not really be used by everyone).}
  
  spec.homepage      = "https://github.com/chtz/simplerubysteps"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.files << "lib/deploy.sh"
  spec.files << "lib/destroy.sh"
  spec.files << "lib/workflow-run.sh"
  spec.files << "lib/statemachine.yaml"
  spec.files << "lib/function.rb"

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.executables << "simplerubysteps-deploy"
  spec.executables << "simplerubysteps-destroy"
  spec.executables << "simplerubysteps-workflow-run"
  
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
end
