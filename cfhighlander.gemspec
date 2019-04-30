lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cfhighlander/version"

Gem::Specification.new do |spec|
  spec.name          = "cfhighlander"
  spec.version       = Cfhighlander::VERSION
  spec.version       = "#{spec.version}.alpha.#{Time.now.getutc.to_i}" if ENV['TRAVIS'] and ENV['TRAVIS_BRANCH'] != 'master'
  spec.authors       = ["Nikola Tosic", "aaronwalker", "Guslington"]
  spec.email         = ["theonestackcfhighlander@gmail.com"]

  spec.summary       = %q{DSL on top of cfndsl. Manage libraries of cloudformation components}
  spec.description   = %q{DSL on top of cfndsl. Manage libraries of cloudformation components}
  spec.homepage      = "https://github.com/theonestack/cfhighlander/blob/master/README.md"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "http://mygemserver.com"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'highline', '>=1.7.10','<1.8'
  spec.add_runtime_dependency 'thor', '~>0.20', '<1'
  spec.add_runtime_dependency 'cfndsl', '~>0.16', '<1'
  spec.add_runtime_dependency 'rubyzip', '>=1.2.1', '<2'
  spec.add_runtime_dependency 'aws-sdk-core', '~> 3','<4'
  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-ec2', '~> 1', '<2'
  spec.add_runtime_dependency 'aws-sdk-cloudformation', '~> 1', '<2'
  spec.add_runtime_dependency 'git', '~> 1.4', '<2'
  spec.add_runtime_dependency 'netaddr', '~> 1.5', '>= 1.5.1'
  spec.add_runtime_dependency 'duplicate','~> 1.1'

  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rake", "~> 4.14"
end
