#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools
  module Resource

    # The supported file format for vector icons depend on the platform.
    VECTOR_FILETYPE = Sketchup.platform == :platform_osx ? 'pdf' : 'svg'

    def self.get_icon_path(path)
      return path unless Sketchup.version.to_i > 15
      vector_icon = self.get_vector_path(path)
      File.exist?(vector_icon) ? vector_icon : path
    end

    def self.get_vector_path(path)
      dir = File.dirname(path)
      basename = File.basename(path, '.*')
      File.join(dir, "#{basename}.#{VECTOR_FILETYPE}")
    end

    def self.create_cursor(filename, x = 0, y = 0)
      path = File.join(PATH_CURSORS, 'quad_edge.png')
      cursor_path = self.get_icon_path(path)
      UI.create_cursor(cursor_path, x, y)
    end

  end # module
end # module
