require 'singleton'

module Erma
  class MonitoringEngine
    include Singleton

     # Starts up the monitoring engine. This method should be called before
     # using ERMA.
     #
     # This call initializes the system and calls startup() on the
     # MonitorProcessorFactory supplied. Therefore, the
     # MonitorProcessorFactory to be used should have been set prior to calling
     # this method.
     #
     # *This method is not thread-safe.* Clients should take care to ensure
     # that multithreaded access to this method is synchronized.
    def startup
      @enabled = true
    end

    def enabled?
      @enabled
    end
  end
end
