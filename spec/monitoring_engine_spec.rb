require File.dirname(File.expand_path(__FILE__)) + '/spec_helper'

describe Erma::MonitoringEngine do
  before do
    @engine = Erma::MonitoringEngine.instance
    @engine.enabled = true
    @engine.processor_factory = stub('MockProcessorFactory', :null_object => true)
    @engine.startup
  end

  after { @engine.shutdown }

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

  describe 'Monitor callback', :shared => true do
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

  describe "processing init_monitor callback" do
    before do 
      @monitor = stub_everything('mock_monitor')
    end

    it "should set the created_at attribute on the monitor as serializable and locked" do
      attr_holder = mock('attr_holder')
      @monitor.should_receive(:set).with(:created_at, anything).and_return(attr_holder)
      @monitor.should_receive(:set).with(:thread_id, anything).and_return(stub_everything)
      attr_holder.should_receive(:serializable).and_return(attr_holder)
      attr_holder.should_receive(:lock)
      @engine.init_monitor(@monitor)
    end

    it "should set the thread ID attribute on the monitor and serializable and locked" do
      attr_holder = mock('attr_holder')
      @monitor.should_receive(:set).with(:created_at, anything).and_return(stub_everything)
      @monitor.should_receive(:set).with(:thread_id, Thread.current.__id__).and_return(attr_holder)
      attr_holder.should_receive(:serializable).and_return(attr_holder)
      attr_holder.should_receive(:lock)
      @engine.init_monitor(@monitor)
    end

    it "should set inherited attributes on monitor"

    it "should do nothing if not enabled" do
      @engine.enabled = false
      @engine.init_monitor(mock('mock_monitor'))
    end
  end

  describe "processing monitor_created callback" do
    before { @callback_method = :monitor_created }
    it_should_behave_like 'Monitor callback'
  end

  describe "processing composite_monitor_started callback" do
    before { @callback_method = :composite_monitor_started }
    it_should_behave_like 'Monitor callback'
  end

  describe "processing composite_monitor_completed callback" do
    before { @callback_method = :composite_monitor_completed }
    it_should_behave_like 'Monitor callback'
  end

  describe "processing process callback" do
    before { @callback_method = :process }
    it_should_behave_like 'Monitor callback'
  end

  describe "global_attributes" do
    it "should be included in the inheritable_attributes call" do
      @engine.set('foo', 12)
      @engine.inheritable_attributes['foo'].should == 12
    end

    it "should be able to be overridden" do
      @engine.set('foo', 12)
      @engine.set('foo', 13)
      @engine.inheritable_attributes['foo'].should == 13
    end

    it "should be global across threads" do
      @engine.set('foo', 12)
      thread = Thread.new { @engine.inheritable_attributes['foo'].should == 12 }
      thread.join
    end
  end

  describe "inherited_attributes" do
    before do
      @monitor = stub_everything("mock_monitor")
    end

    it "should include inheritable attributes on parent Monitors" do
      @monitor.should_receive(:inheritable_attribute_holders).
    end
  end
end
