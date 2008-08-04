module Erma
  class Monitor
    def initialize(name)
      self.attributes['name'] = AttributeHolder.new(name, false, false)
    end

    # Returns the value for the attribute with the given key.
    def [](key)
      attributes[key].value
    end

    def attributes
      @attributes ||= {}
    end

    # True if the attribute for the given key is set on this Monitor.
    def has_attribute?(key)
      !! attributes[key]
    end

    # True if the attribute for the given key is locked.
    def locked?(key)
      attributes[key].locked?
    end

    # True if the attribute for the given key is marked as serializable.
    def serializable?(key)
      attributes[key].serializable?
    end

    def set(key, value)
      self.attributes[key] = AttributeHolder.new(value, false, false)
    end

    # Holds a Monitor attribute value and associated metadata.
    class AttributeHolder
      attr_reader :value
      def initialize(value, serializable, locked)
        @value = value
        @serializable = serializable
        @locked = locked
      end

      def serializable
        @serializable = true
        self
      end

      def serializable?
        @serializable
      end

      def lock
        @locked = true
        self
      end

      def locked?
        @locked
      end
    end
  end
end
