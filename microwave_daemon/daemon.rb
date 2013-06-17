#!/usr/bin/env ruby
#
# Allows multiple programs to communicate with the Arduino
#
require 'rubygems'
require 'socket'
require 'thread'
require 'serialport'

PORT = 3141
ARDUINO = "/dev/serial/by-id/usb-FTDI_FT232R_USB_UART_AH01GMF6-if00-port0"

def wait_for_serial_connection
  connected = false
  while !connected
    begin
      @microwave = SerialPort.new(ARDUINO, 9600, 8, 1, SerialPort::NONE)
      @microwave.read_timeout = 0
      puts "Connected to arduino."
      connected = true
    rescue
      sleep 1
    end
  end
end

wait_for_serial_connection

@server    = TCPServer.new(PORT)

at_exit do
  @microwave.close
end

loop do
  Thread.start(@server.accept) do |client|
    begin

      puts "Client connected."

      while request = client.gets
        action, command = request.chomp.split(": ")

        case action
        when 'info'
          # Send info request
          @microwave.puts "i"
          # Receive info
          info = @microwave.gets.chomp
          client.puts info

        when 'serial'
          puts "Sending command to Arduino: #{command}"
          # Just relay command to serial
          @microwave.puts command
        end
      end

      client.close
      puts "Connection closed."
    rescue Exception => ex
      puts "Error from arduino serial connection!"
      puts ex.inspect

      # Close TCP connection
      client.close

      # Repair serial connection
      wait_for_serial_connection

      puts "Reconnected!"
    end
  end
end
