#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'set'

module TT::Plugins::QuadFaceTools
module Settings

  @cache = {}
  @observers = Set.new

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
    self.trigger_event(:on_setting_change, key, value)
    value
  end

  def self.add_observer(observer)
    @observers.add(observer)
  end

  def self.remove_observer(observer)
    @observers.delete(observer)
  end

  # @private
  #
  # @param [Symbol] event
  # @param [Array] args
  def self.trigger_event(event, *args)
    @observers.each { |observer|
      next unless observer.respond_to?(event)

      observer.send(event, self, *args)
    }
  end

end # module Settings
end # module
