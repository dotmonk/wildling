#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(root, "lib"))

require "wildling"

Wildling::Cli.main
