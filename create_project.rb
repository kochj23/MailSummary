#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.new('Mail Summary.xcodeproj')

# Create target
target = project.new_target(:application, 'Mail Summary', :osx, '13.0')

# Create main group
main_group = project.main_group.new_group('Mail Summary')

# Add source files
['MailSummaryApp.swift', 'ContentView.swift', 'MailEngine.swift', 'MailParser.swift', 'EmailModels.swift', 'AICategorizationEngine.swift'].each do |file|
  file_ref = main_group.new_reference(file)
  target.source_build_phase.add_file_reference(file_ref)
end

# Configure build settings
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'Mail Summary'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.jordankoch.MailSummary'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['INFOPLIST_FILE'] = 'Mail Summary/Info.plist'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
end

project.save

puts "✅ Created Mail Summary.xcodeproj"
