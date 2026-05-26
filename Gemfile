source "https://rubygems.org"

gem "fastlane", ">= 2.220.0"
gem "jwt",      ">= 2.7.0"
gem "json",     "~> 2.7.2"

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
