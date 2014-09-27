#!/usr/bin/env ruby
require 'rubygems'
require 'serialport'

PORT_STR = "/dev/ttyACM0"

ser = SerialPort.new(PORT_STR, 9600, 8, 1, SerialPort::NONE)

i = 0
while true do
  puts "#{i}) Writing to #{PORT_STR}..."
  ser.write [0,1,12].pack('c*') + "\n"

  sleep 2
  i += 1
end
