require File.dirname(File.expand_path(__FILE__)) + '/spec_helper'

describe Erma::MonitoringEngine do
  it "should be enabled after startup" do
    Erma::MonitoringEngine.instance.startup
    Erma::MonitoringEngine.instance.should be(:enabled)
  end
end
