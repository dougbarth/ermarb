$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Ermarb; end

module Erma; end

require 'erma/monitoring_engine'
require 'erma/monitor'
require 'erma/event_monitor'
