#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), 'lib')

BARCODE_SCANNER_EVENT = "/dev/input/by-id/usb-040b_6543-event-kbd"
ARDUINO_DAEMON_PORT = 3141

require 'rubygems'
require 'yaml'
require 'thread'
require 'microwave'
require 'microwave_cooking_db'
require 'confstruct'
require 'twitter'

Config = Confstruct::Configuration.new(YAML.load_file(File.expand_path("../config.yml", __FILE__)))

Twitter.configure do |config|
  config.consumer_key       = Config.twitter.consumer_key
  config.consumer_secret    = Config.twitter.consumer_secret
  config.oauth_token        = Config.twitter.oauth_token
  config.oauth_token_secret = Config.twitter.oauth_token_secret
end

connected = false
until connected
  begin
    @microwave = Microwave.new
    connected = true
  rescue Exception => ex
    p $!, *$@
    sleep 2
  end
end

@microwave.start_thread!(:fetch_microwave_info)
@microwave.start_thread!(:fetch_barcodes)
@microwave.start_thread!(:process_barcodes).join
