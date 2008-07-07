module Erma
  class Monitor
    def initialize(name)
      self.attributes['name'] = AttributeHolder.new(name, false, false)
    end

    def [](key)
      attributes[key].value
    end

    def attributes
      @attributes ||= {}
    end

    # Holds a Monitor attribute value and associated metadata.
    class AttributeHolder
      attr_reader :value
      def initialize(value, serializable, locked)
        @value = value
        @serializable = serializable
        @locked = locked
      end
    end
  end
end
