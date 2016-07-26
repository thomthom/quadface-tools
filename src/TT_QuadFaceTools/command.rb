#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::QuadFaceTools

  class Command < UI::Command

    # SketchUp allocate the object by implementing `new` - probably part of
    # older legacy implementation when that was the norm.
    def self.new(title, &block)
      super(title) {
        begin
          block.call
        rescue Exception => exception
          ERROR_REPORTER.handle(exception)
        end
      }
    end

  end # class

end # module
