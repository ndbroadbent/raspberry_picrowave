#!/bin/ruby

require 'rubyserial'

serial = Serial.new '/dev/ttyACM0', 57600

while true do
  serial.write [0,1,12].pack('c*') + "\n"

  sleep 1
end
