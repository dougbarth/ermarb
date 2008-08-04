require 'singleton'
require 'monitor'

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
      stack_map.clear

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

    # Shuts down the MonitoringEngine if it is running. After it is shutdown,
    # the MonitoringEngine will be started up.
    #
    # *This method is not thread-safe.* Clients should take care to ensure
    # that multithreaded access to this method is synchronized.
    def restart
      shutdown if running?
      startup
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

      inherit_attributes(monitor)
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
    def monitor_started(monitor)
      return unless processing?
      handle_monitor(monitor, :monitor_started)
    end
    
    # Adds the supplied CompositeMonitor to the stack for this thread. 
    #
    # This method should be called by all CompositeMonitor implementations
    # before they call monitorStarted().
    def composite_monitor_started(monitor)
      return unless processing?
      
      monitor_stack.push(monitor)
    end

    # Pops this monitor off the top of the stack. If this monitor is not on the
    # top of the stack nor found anywhere within the stack, the monitor is
    # ignored, as this is an error in instrumentation. If the monitor is
    # found within the stack, the top of the stack is repeatedly popped and
    # processed until this monitor is on the the top.
    #
    # This method should be called by all CompositeMonitor implementations
    # before they call process().
    def composite_monitor_completed(monitor)
      return unless processing?

      return unless monitor_stack.include?(monitor)

      while (missed_mon = monitor_stack.pop) != monitor
        process(missed_mon)
      end
    end

    # A lifecycle method that notifies observing MonitorProcessors that a
    # monitor is ready to be processed. All monitor implementations should call this 
    # method as the last call of their lifecycle.
    def process(monitor)
      return unless processing?
      handle_monitor(monitor, :process)
    end

    
    # Obtains the first CompositeMonitor found on the per thread stack that has
    # its name attribute equal to the supplied name. This method should be used
    # in situations where stateless code is unable to hold a reference to
    # the CompositeMonitor that was originally created. Supplying the name
    # value is needed to ensure that instrumentation errors in code called by
    # users of this method does not interfere with the ability to correctly
    # obtain the original CompositeMonitor.
    def get_composite_monitor_named(name)
      raise 'Must supply a non-nil name' if name.nil?
      monitor_stack.reverse.find {|m| m['name'] == name} 
    end

    def global_attributes
      @global_attributes ||= {}
    end

    def inheritable_attributes
      inheritable_attributes = {}
      global_attributes.each do |key, value|
        inheritable_attributes[key] = Erma::Monitor::AttributeHolder.new(value, false, false)
      end

      monitor_stack.each do |ancestor|
        inheritable_attributes.merge!(ancestor.inheritable_attribute_holders)
      end

      inheritable_attributes
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

    def inherit_attributes(monitor)
      global_attributes.each do |key, value|
        monitor.set(key, value)
      end
    end

    def initialize
      self.enabled = true
    end

    def monitor_stack
      stack_map.synchronize do
        stack_map[Thread.current.__id__] ||= []
      end
    end

    def stack_map
      @stack_map ||= begin
        map = {}
        map.extend(MonitorMixin)
      end
    end
  end
end
