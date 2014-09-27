#!/usr/bin/env ruby
require 'rubygems'
require 'serialport'

PORT_STR = "/dev/ttyACM0"

@ser = SerialPort.new(PORT_STR, 9600, 8, 1, SerialPort::NONE)

puts "Writing to #{PORT_STR}..."

def send_cmd(cmd, p1, p2 = 0)
  bytes = [0x01, cmd, p1, p2, 0x17]
  puts "Sending: #{bytes.inspect}"
  @ser.write bytes.pack('c*')
end

# clear
send_cmd 5, 11
sleep 0.2

send_cmd 1, 1
sleep 0.2

puts "Time: #{ARGV[0]}"
send_cmd 2, 0, ARGV[0].to_i

sleep 0.2

puts "Power: #{ARGV[1]}"
send_cmd 4, ARGV[1].to_i


