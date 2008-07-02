require 'singleton'

module Erma
  # The engine that controls basic correlation of monitors as they are collected
  # and submitted to the engine. All monitors should call these methods at key
  # points in their lifetime so that they are processed correctly.
  class MonitoringEngine
    include Singleton

    attr_accessor :processor_factory

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
      raise 'processor_factory has not been set' unless processor_factory

      processor_factory.startup

      @running = true
    end

    # Shuts down the monitoring engine. This method should be called before
    # shutting down the application to give the ERMA system a chance to cleanly
    # close all its resources.
    #
    # This call disables ERMA and calls shutdown() on the
    # MonitorProcessorFactory supplied.
    #
    # *This method is not thread-safe.* Client should take care to ensure
    # that multithreaded access to this method is synchronized.
    def shutdown
      if running?
        @running = false
        processor_factory.shutdown
        processor_factory = nil
      end
    end

    # A lifecycle method that initializes the Monitor. All monitor
    # implementations must call this methods before setting any attributes on
    # themselves.
    #
    # After this method returns, the monitor will have had any implicitly
    # inherited and global attributes applied.
    def init_monitor(monitor)
      return unless processing?
      monitor.set(:created_at, Time.now).serializable.lock
      monitor.set(:thread_id, Thread.current.__id__).serializable.lock
    end

    # A lifecycle method that notifies observing MonitorProcessors that a new
    # monitor has been created. All monitor implementations should call this
    # method after setting attributes known at creation on themselves.
    def monitor_created(monitor)
      return unless processing?
      handle_monitor(monitor, :monitor_created)
    end

    # A lifecylce method that notifies observing MonitorProcessors that a
    # monitor has been started. All monitor implementations that have a
    # start-stop concept should call this monitor at start.
    def composite_monitor_started(monitor)
      return unless processing?
      handle_monitor(monitor, :composite_monitor_started)
    end

    # A lifecycle method that notifies observing MonitorProcessors that a
    # monitor is ready to be processed. All monitor implementations should call
    # as the last call of their lifecycle.
    def composite_monitor_completed(monitor)
      return unless processing?
      handle_monitor(monitor, :composite_monitor_completed)
    end

    # A lifecycle method that notifies observing MonitorProcessors that a
    # monitor is ready to be processed. All monitor implementations should call this 
    # method as the last call of their lifecycle.
    def process(monitor)
      return unless processing?
      handle_monitor(monitor, :process)
    end

    def set(attr_key, attr_val)
      @global_attributes ||= {}
      @global_attributes[attr_key] = attr_val
    end

    def inheritable_attributes
      @global_attributes
    end

    attr_writer :enabled
    def enabled?
      @enabled
    end

    def running?
      @running
    end

    # Returns true if the MonitoringEngine is processing Monitors.
    def processing?
      enabled? && running?
    end

    private
    def handle_monitor(monitor, callback_method)
      begin
        processors = processor_factory.processors_for_monitor(monitor)
        processors.each do |p| 
          begin
            p.send(callback_method, monitor) 
          rescue Exception
            # Swallowed
          end
        end
      rescue Exception
        # Swallowed
      end
    end

    def initialize
      puts 'Calling initialize'
      self.enabled = true
    end
  end
end
