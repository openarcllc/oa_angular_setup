# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oa_angular_setup/version'

Gem::Specification.new do |spec|
  spec.name          = "oa_angular_setup"
  spec.version       = OaAngularSetup::VERSION
  spec.authors       = ["Mark VanArsdale"]
  spec.email         = ["mark@openarc.net"]

  spec.summary       = "A gem to setup angular factories"
  spec.description   = "A gem to setup angular factories"
  spec.homepage      = "https://github.com/openarcllc/oa_angular_setup"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "localhost:8808"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = Dir["{lib}/**/*"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "mechanize"
  spec.add_runtime_dependency "nokogiri"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", '~> 0'
end
