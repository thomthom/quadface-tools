require 'fileutils'

PROGRAM_FILES = File.expand_path(ENV['PROGRAMW6432'])

SOLUTION_PATH = File.expand_path(File.join(__dir__, '..'))
EXTENSION_SOURCE_PATH = File.join(SOLUTION_PATH, 'src')
EXTENSION_SUPPORT_PATH = File.join(EXTENSION_SOURCE_PATH, 'TT_QuadFaceTools')
EXTENSION_IMAGE_PATH = File.join(EXTENSION_SUPPORT_PATH, 'Icons')

# Illustrator Export:
#
# 1. Export... > Export As...
#
# 2. Use Artboards: YES
#
# 3. SVG Options:
#    * Styling: Inline Style
#    * Font: SVG
#    * Images: Preserve
#    * Object IDs: Layer Names
#    * Decimal: 2
#    * Minify: YES
#    * Responsive: YES

module Inkscape

  INKSCAPE_PATH = File.join(PROGRAM_FILES, 'Inkscape')
  INKSCAPE = File.join(INKSCAPE_PATH, 'bin', 'inkscape.com')

  puts "Inkscape: #{INKSCAPE} (#{File.exist?(INKSCAPE)})"

  def self.convert_svg_to_pdf(input, output)
    svg_filename = self.normalise_path(input)
    pdf_filename = self.normalise_path(output)
    arguments = %("#{svg_filename}" -C -o "#{pdf_filename}")
    self.command(arguments)
  end

  def self.convert_svg_to_png(input, output, size)
    svg_filename = self.normalise_path(input)
    png_filename = self.normalise_path(output)
    arguments = %("#{svg_filename}" -o "#{png_filename}" -w #{size} -h #{size})
    self.command(arguments)
  end

  def self.normalise_path(path)
    path.tr('/', '\\')
  end

  def self.command(arguments)
    inkscape = INKSCAPE.tr('/', '\\')
    inkscape = self.normalise_path(INKSCAPE)
    command = %("#{inkscape}" #{arguments})
    puts command
    puts `#{command}`
  end

end # module

# source_path = File.join(SOLUTION_PATH, 'Media', 'Toolbar Icons')
source_path = EXTENSION_IMAGE_PATH
target_path = EXTENSION_IMAGE_PATH

puts "Source path: #{source_path}"
puts "Target path: #{target_path}"

large_postfix = '_24'
small_postfix = '_16'
copy_postfix = ' copy'

filter = File.join(source_path, '*.svg')
Dir.glob(filter).each { |source_file|
  # Skip the "small" SVG images.
  # next if source_file.end_with?("#{small_postfix}.svg")

  puts ''
  puts source_file

  filename = File.basename(source_file)
  basename = File.basename(source_file, '.svg')

  # When saving files from artboards in Illustrator it appends the board name
  # to the file. For SVG toolbar icons we only export the "large" variant and
  # get the unwanted postfix. We check for this and remove it.
  # puts "> Basename: #{basename}"
  # if basename.end_with?(large_postfix)
  #   # First we just detect the postfix.
  #   basename = File.basename(basename, large_postfix)
  #   puts "> Strip Large Postfix - Basename: #{basename}"
  # end

  # TODO: Create Illustrator Script to save out SVG from each artboard.
  if basename.end_with?(copy_postfix)
    # First we just detect the postfix.
    basename = File.basename(basename, copy_postfix)
    puts "> Strip Copy Postfix - Basename: #{basename}"
  end

  # Then we generate the desired filenames.
  svg = "#{basename}.svg"
  pdf = "#{basename}.pdf"
  png = "#{basename}.png"

  svg_filename = File.join(target_path, svg)
  pdf_filename = File.join(target_path, pdf)
  png_filename = File.join(target_path, png)

  # Now we actually rename the SVG files if they had the post-fix.
  # idential = false
  # if File.exist?(svg_filename)
  #   source = File.binread(source_file)
  #   target = File.binread(svg_filename)
  #   idential = (source == target)
  # end
  # puts
  # puts "Export SVG:"
  # puts "> #{filename} => #{svg}"
  # if idential
  #   puts "Source identical to target - skipping..."
  #   next
  # end
  # options = {
  #   :preserve => true,
  #   :verbose => true
  # }
  # p FileUtils.install(source_file, svg_filename, options)

  # Generate the PDF.
  puts
  puts "Export PDF:"
  puts "> #{svg} => #{pdf}"
  p Inkscape.convert_svg_to_pdf(source_file, pdf_filename)
  puts "Done!"

  puts
  puts "Export PNG:"
  puts "> SVG => PNG"
  size = basename.end_with?(large_postfix) ? 32 : 24
  p Inkscape.convert_svg_to_png(source_file, png_filename, size)
  # source_large_svg = File.join(source_path, "#{basename}#{large_postfix}.svg")
  # source_small_svg = File.join(source_path, "#{basename}#{small_postfix}.svg")
  # png_large_filename = File.join(target_path, "#{basename}#{large_postfix}.png")
  # png_small_filename = File.join(target_path, "#{basename}#{small_postfix}.png")
  # puts "> #{source_large_svg} => #{png_large_filename}"
  # puts "> #{source_small_svg} => #{png_small_filename}"
  # p Inkscape.convert_svg_to_png(source_large_svg, png_large_filename, 32)
  # p Inkscape.convert_svg_to_png(source_small_svg, png_small_filename, 24)
}
