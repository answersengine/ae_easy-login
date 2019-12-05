
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "ae_easy-login"
  spec.version       = "0.0.3"
  spec.authors       = ["Eduardo Rosales"]
  spec.email         = ["eduardo@datahen.com"]

  spec.summary       = %q{(Deprecated: Use dh_easy-login gem instead.) Compatibility alias for DataHen Easy toolkit login flow module}
  spec.description   = %q{(Deprecated: Use dh_easy-login gem instead.) Compatibility alias for DataHen Easy toolkit login flow module allows to handle login and session expire recovery with ease.}
  spec.homepage      = "https://datahen.com"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/answersengine/ae_easy-login"
    # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>= 2.2.2'

  spec.add_dependency 'dh_easy-login', '>= 0'
  spec.add_dependency 'ae_easy-core', '>= 0.2.1'
  spec.add_development_dependency 'bundler', '>= 1'
  spec.add_development_dependency 'rake', '~> 10'
  spec.add_development_dependency 'minitest', '~> 5'
  spec.add_development_dependency 'byebug', '>= 0'
end
