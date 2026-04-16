#!/usr/bin/env ruby
# Adds the 14 new Swift files to the FullBars Xcode project & target.
# Run from the project root (the folder containing FullBars.xcodeproj).

require 'xcodeproj'

PROJECT_PATH = 'FullBars.xcodeproj'
TARGET_NAME  = 'FullBars'

# Files to add, relative to FullBars.xcodeproj's parent directory.
# The path inside "FullBars/..." is the source-folder path on disk.
FILES = [
  { path: 'FullBars/Models/HomeConfiguration.swift',            group: 'FullBars/Models' },
  { path: 'FullBars/Models/Room.swift',                         group: 'FullBars/Models' },
  { path: 'FullBars/Models/Doorway.swift',                      group: 'FullBars/Models' },
  { path: 'FullBars/Models/DevicePlacement.swift',              group: 'FullBars/Models' },
  { path: 'FullBars/Services/RoomScanCoordinator.swift',        group: 'FullBars/Services' },
  { path: 'FullBars/Utilities/HomeSelection.swift',             group: 'FullBars/Utilities' },
  { path: 'FullBars/Views/AppShell.swift',                      group: 'FullBars/Views' },
  { path: 'FullBars/Views/HomeScan/HomeScanHomeView.swift',     group: 'FullBars/Views/HomeScan' },
  { path: 'FullBars/Views/HomeScan/RoomScanView.swift',         group: 'FullBars/Views/HomeScan' },
  { path: 'FullBars/Views/Onboarding/OnboardingFlow.swift',     group: 'FullBars/Views/Onboarding' },
  { path: 'FullBars/Views/Results/ResultsHomeView.swift',       group: 'FullBars/Views/Results' },
  { path: 'FullBars/Views/Results/RoomDetailView.swift',        group: 'FullBars/Views/Results' },
  { path: 'FullBars/Views/Results/ShareBadgeView.swift',        group: 'FullBars/Views/Results' },
  { path: 'FullBars/Views/Settings/SettingsHomeView.swift',     group: 'FullBars/Views/Settings' },
]

project = Xcodeproj::Project.open(PROJECT_PATH)
target  = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target '#{TARGET_NAME}' not found" unless target

def ensure_group(project, path_components)
  group = project.main_group
  path_components.each do |name|
    existing = group.groups.find { |g| g.display_name == name || g.path == name }
    if existing
      group = existing
    else
      group = group.new_group(name, name)
      puts "  + created group: #{name}"
    end
  end
  group
end

added = 0
skipped = 0

FILES.each do |f|
  unless File.exist?(f[:path])
    puts "SKIP (not on disk): #{f[:path]}"
    skipped += 1
    next
  end

  # Skip if file is already referenced somewhere in the project
  already = project.files.any? { |ref| ref.real_path.to_s.end_with?(f[:path]) }
  if already
    puts "SKIP (already in project): #{f[:path]}"
    skipped += 1
    next
  end

  group_components = f[:group].split('/')
  group = ensure_group(project, group_components)

  file_ref = group.new_reference(File.expand_path(f[:path]))
  target.add_file_references([file_ref])
  puts "ADDED: #{f[:path]}"
  added += 1
end

project.save
puts "\nDone. Added #{added}, skipped #{skipped}."
