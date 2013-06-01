#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), 'lib')

BARCODE_SCANNER_EVENT = "/dev/input/by-id/usb-Metrologic_Metrologic_Scanner-event-kbd"
ARDUINO_DAEMON_PORT = 3141

require 'rubygems'
require 'yaml'
require 'thread'
require 'microwave'

connected = false
until connected
  begin
    preparation_steps = YAML.load_file(File.expand_path('../upc_preparation_steps.yml', __FILE__))
    @microwave = Microwave.new(preparation_steps)
    connected = true
  rescue Exception => ex
    puts ex.inspect
    sleep 2
  end
end

@microwave.start_thread!(:fetch_arduino_info)
@microwave.start_thread!(:fetch_barcodes)
@microwave.start_thread!(:process_barcodes).join
