sketchup_version = ARGV[0].to_i

program_files_32 = 'C:/Program Files (x86)'
program_files_64 = 'C:/Program Files'

# This assumes we are debuggin 64bit is availible.
if sketchup_version > 14
  program_files = program_files_64
else
  program_files = program_files_32
end

if sketchup_version > 8
  version = "20#{sketchup_version}"
else
  version = sketchup_version.to_s
end

sketchup_path = File.join(program_files, "SketchUp", "SketchUp #{version}")
sketchup = File.join(sketchup_path, "SketchUp.exe")

command = %{"#{sketchup}" -rdebug "ide port=7000"}
spawn(command)
