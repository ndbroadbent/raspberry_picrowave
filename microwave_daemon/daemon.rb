#!/usr/bin/env ruby
#
# Allows multiple programs to communicate with the Arduino
#
require 'rubygems'
require 'socket'
require 'thread'
require 'json'
require File.expand_path('../lib/ext/microwave', __FILE__)

PORT = 3141

@microwave = MicrowaveExt.new
@server    = TCPServer.new(PORT)

Thread.start(@microwave) do |m|
  m.touchpad_loop
end

loop do
  Thread.start(@server.accept) do |client|
    begin
      puts "Client connected."

      while data = client.gets
        request = JSON.parse(data)

        if request['get_info']
          # Fetch info and send to TCP client
          client.puts(@microwave.get_info)

        elsif command = request['command']
          puts "Sending command to Microwave: #{command}"
          @microwave.send_command(command)
        end
      end

      client.close
      puts "Connection closed."

    rescue Exception => ex
      puts "Error from microwave daemon!"
      puts ex.inspect

      # Close TCP connection
      client.close
    end
  end
end
