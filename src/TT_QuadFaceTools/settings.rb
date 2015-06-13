#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::QuadFaceTools
module Settings

  @cache = {}

  def self.read(key, default = nil)
    if @cache.key?(key)
      @cache[key]
    else
      value = Sketchup.read_default(PLUGIN_ID, key, default)
      @cache[key] = value
      value
    end
  end

  def self.write(key, value)
    @cache[key] = value
    Sketchup.write_default(PLUGIN_ID, key, value)
    value
  end

end # module Settings
end # module
