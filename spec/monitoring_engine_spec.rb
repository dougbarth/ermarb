require File.dirname(File.expand_path(__FILE__)) + '/spec_helper'

describe Erma::MonitoringEngine do
  before do
    @engine = Erma::MonitoringEngine.instance
    @engine.enabled = true
    @engine.processor_factory = stub('MockProcessorFactory', :null_object => true)
    @engine.restart
  end

  it "should be enabled after startup" do
    @engine.startup
    @engine.should be_enabled
  end

  describe "without a processor_factory set" do
    before do 
      @engine.shutdown
      @engine.processor_factory = nil 
    end

    it "should raise an Error when startup is called" do
      lambda { @engine.startup }.should raise_error
    end

    it "should not throw an error when shutdown is called afterwards" do
      lambda { @engine.startup }.should raise_error
      @engine.shutdown
    end
  end

  describe "without a decomposer set" do
    it "should raise an Error when startup is called" 
    it "should not throw an error when shutdown is called afterwards" 
  end

  it "should call processor_factory.startup when startup is called" do
    @engine.processor_factory.should_receive(:startup)
    @engine.startup
  end

  it "should let processor_factory.startup Errors pass through to the client code" do
    @engine.processor_factory.should_receive(:startup).and_raise
    lambda { @engine.startup }.should raise_error
  end

  it "should call processor_factory.shutdown when shutdown is called" do
    @engine.startup
    @engine.processor_factory.should_receive(:shutdown)
    @engine.shutdown
  end

  it "should let processor_factory.shutdown Errors pass through to the client code" do
    @engine.startup
    @engine.processor_factory.should_receive(:shutdown).and_raise
    lambda { @engine.shutdown }.should raise_error
  end

  it "should not be running when processor_factory.shutdown raises an Error" do
    @engine.startup
    @engine.processor_factory.should_receive(:shutdown).and_raise
    lambda { @engine.shutdown }.should raise_error
    @engine.should_not be_running
  end

  describe "restart" do
    it "should call shutdown" do
      @engine.should_receive(:shutdown)
      @engine.restart
    end

    it "should not call shutdown if not running" do
      @engine.shutdown
      @engine.should_receive(:shutdown).never
      @engine.restart
    end

    it "should call startup" do
      @engine.should_receive(:startup)
      @engine.restart
    end
  end

  # TODO Java version should have this concept instead of confusing isEnabled() method
  describe "processing?" do
    it "should be true if enabled and running" do
      @engine.enabled = true
      @engine.startup
      @engine.should be_processing
    end

    it "should be false if not enabled" do
      @engine.enabled = false
      @engine.startup
      @engine.should_not be_processing
    end

    it "should be false if not running" do
      @engine.enabled = true
      @engine.shutdown
      @engine.should_not be_processing
    end
  end

  describe 'pass to processors callback', :shared => true do
    it "should do nothing if not enabled" do
      # TODO suggest this as an extra test case in Java ERMA impl
      @engine.enabled = false
      @engine.processor_factory.should_not_receive(:processors_for_monitor)
      @engine.send(@callback_method, mock('fake_monitor'))
    end

    it "should do nothing if not running" do
      @engine.shutdown
      @engine.processor_factory.should_not_receive(:processors_for_monitor)
      @engine.send(@callback_method, mock('fake_monitor'))
    end

    it "should ask the MonitorProcessorFactory for the applicable MonitorProcessors" do
      @engine.processor_factory.should_receive(:processors_for_monitor)
      @engine.send(@callback_method, mock('fake_monitor'))
    end

    it "should swallow Errors raised by MonitorProcessorFactory.processors_for_monitor" do
      @engine.processor_factory.should_receive(:processors_for_monitor).and_raise
      @engine.send(@callback_method, mock('fake_monitor'))
    end

    it "should pass the monitor to each processor's callback method" do
      mock_processors = [mock('Processor1'), mock('Processor2')]
      mock_processors.each {|p| p.should_receive(@callback_method)}
      @engine.processor_factory.should_receive(:processors_for_monitor).and_return(mock_processors)
      @engine.send(@callback_method, mock('fake_monitor'))
    end

    it "should isolate Exceptions raised by individual processors" do
      mock_processors = [mock('Processor1'), mock('Processor2')]
      mock_processors[0].should_receive(@callback_method).and_raise
      mock_processors[1].should_receive(@callback_method)
      @engine.processor_factory.should_receive(:processors_for_monitor).and_return(mock_processors)
      @engine.send(@callback_method, mock('fake_monitor'))
    end

    it "should not raise Exceptions when receiving callbacks before being started" do
      @engine.shutdown
      @engine.send(@callback_method, mock('fake_monitor'))
    end
  end

  describe "processing monitor_created callback" do
    before { @callback_method = :monitor_created }
    it_should_behave_like 'pass to processors callback'
  end

  describe "processing monitor_started callback" do
    before { @callback_method = :monitor_started }
    it_should_behave_like 'pass to processors callback'
  end

  describe "processing process callback" do
    before { @callback_method = :process }
    it_should_behave_like 'pass to processors callback'
  end

  describe "processing init_monitor callback" do
    before do 
      @monitor = Erma::EventMonitor.new('test')
    end

    it "should set the created_at attribute on the monitor as serializable and locked" do
      @engine.init_monitor(@monitor)
      @monitor.should have_attribute(:created_at)
      @monitor.should be_locked(:created_at)
      @monitor.should be_serializable(:created_at)
    end

    it "should set the thread ID attribute on the monitor and serializable and locked" do
      @engine.init_monitor(@monitor)
      @monitor.should have_attribute(:thread_id)
      @monitor.should be_locked(:thread_id)
      @monitor.should be_serializable(:thread_id)
      @monitor[:thread_id].should == Thread.current.__id__
    end

    it "should set inherited attributes on monitor"

    it "should inherit global attributes" do
      @engine.global_attributes['foo'] = 10
      @engine.init_monitor(@monitor)
      @monitor['foo'].should == 10
    end

    it "should do nothing if not enabled" do
      @engine.enabled = false
      @engine.init_monitor(mock('mock_monitor'))
    end
  end

  describe "processing composite_monitor_started callback" do
    it "should remember the monitor added" do
      @monitor = Erma::Monitor.new('foo')
      @engine.composite_monitor_started(@monitor)
      @engine.get_composite_monitor_named('foo').should == @monitor
    end

    it "should maintain a stack of Monitors" do
      @engine.composite_monitor_started(Erma::Monitor.new('foo'))
      @newer_monitor = Erma::Monitor.new('foo')
      @engine.composite_monitor_started(@newer_monitor)
      @engine.get_composite_monitor_named('foo').should == @newer_monitor
    end

    it "should maintain separate stacks for each thread" do
      threads = []
      2.times do |i|
        threads << Thread.new do 
          monitor = Erma::Monitor.new('foo')
          @engine.composite_monitor_started(monitor)
          Thread.pass
          @engine.get_composite_monitor_named('foo').should == monitor
        end
      end
      threads.each {|t| t.join}
    end

    it "should do nothing if monitoring is not enabled" do
      @engine.enabled = false
      @engine.composite_monitor_started(Erma::Monitor.new('foo'))
      @engine.get_composite_monitor_named('foo').should == nil
    end
  end

  describe "processing composite_monitor_completed callback" do
    it "should pop the monitor from the stack" do
      @monitor = Erma::Monitor.new('foo')
      @engine.composite_monitor_started(@monitor)
      @engine.composite_monitor_completed(@monitor)
      @engine.get_composite_monitor_named('foo').should == nil
    end

    it "should pop only the monitor provided" do
      @parent = Erma::Monitor.new('parent')
      @child = Erma::Monitor.new('child')
      @engine.composite_monitor_started(@parent)
      @engine.composite_monitor_started(@child)
      @engine.composite_monitor_completed(@child)
      @engine.get_composite_monitor_named('child').should == nil
      @engine.get_composite_monitor_named('parent').should == @parent
    end

    it "should ignore double calls" do
      @parent = Erma::Monitor.new('parent')
      @child = Erma::Monitor.new('child')
      @engine.composite_monitor_started(@parent)
      @engine.composite_monitor_started(@child)
      @engine.composite_monitor_completed(@child)
      @engine.composite_monitor_completed(@child)
      @engine.get_composite_monitor_named('child').should == nil
      @engine.get_composite_monitor_named('parent').should == @parent
    end

    it "should process missed monitors" do
      @parent = Erma::Monitor.new('parent')
      @child = Erma::Monitor.new('child')
      @engine.should_receive(:process).with(@child)
      @engine.composite_monitor_started(@parent)
      @engine.composite_monitor_started(@child)
      @engine.composite_monitor_completed(@parent)
    end
  end

  describe "get_composite_monitor_named" do
    it "should raise a RuntimeError when passed nil" do
      lambda { @engine.get_composite_monitor_named(nil) }.should raise_error
    end
  end

  describe "global_attributes" do
    before do
      @engine.global_attributes.clear
    end

    it "should be included in the inheritable_attributes call" do
      @engine.global_attributes['foo'] = 12
      @engine.inheritable_attributes['foo'].value.should == 12
    end

    it "should be able to be overridden" do
      @engine.global_attributes['foo'] = 12
      @engine.global_attributes['foo'] = 13
      @engine.inheritable_attributes['foo'].value.should == 13
    end

    it "should be global across threads" do
      @engine.global_attributes['foo'] = 12
      thread = Thread.new { @engine.inheritable_attributes['foo'].value.should == 12 }
      thread.join
    end
  end

  describe "inheritable_attributes" do
    before do
      @engine.global_attributes.clear

      @monitor = stub_everything("mock_monitor")
      @attr_holders = {:foo => Erma::Monitor::AttributeHolder.new('bar', false, false)}
      @monitor.should_receive(:inheritable_attribute_holders).and_return(@attr_holders)
      @engine.composite_monitor_started(@monitor)
    end

    it "should include inheritable attributes on parent Monitors" do
      @engine.inheritable_attributes.should == @attr_holders
    end
  end
end
