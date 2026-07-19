# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "wildling"

Gem::Specification.new do |spec|
  spec.name          = "wildling"
  spec.version       = Wildling::VERSION
  spec.summary       = "Pattern based string generator library and CLI"
  spec.description   = "Enumerate pattern combinations for wordlists, domains, and test data."
  spec.authors       = ["dotmonk"]
  spec.email         = ["dotmonk@users.noreply.github.com"]
  spec.homepage      = "https://github.com/dotmonk/wildling"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dotmonk/wildling/tree/main/ruby"
  spec.metadata["changelog_uri"] = "https://github.com/dotmonk/wildling/releases"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "bin/*", "help.txt", "README.md"].select { |f| File.file?(f) }
  end
  spec.bindir = "bin"
  spec.executables = ["wildling"]
  spec.require_paths = ["lib"]
end
