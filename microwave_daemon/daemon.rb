#!/usr/bin/env ruby
#
# Allows multiple programs to communicate with the Arduino
#
require 'rubygems'
require 'socket'
require 'thread'
require 'json'
require File.expand_path('../lib/audio_player', __FILE__)
#require File.expand_path('../microwave', __FILE__)
require File.expand_path('../lib/serial_microwave', __FILE__)

PORT = 3141

#@microwave = MicrowaveExt.new
@microwave = SerialMicrowave.new
@server    = TCPServer.new(PORT)

Thread.start(@microwave) do |m|
  while true
    m.touchpad_loop
  end
end

loop do
  Thread.start(@server.accept) do |client|
    begin
      puts "Client connected."

      while data = client.gets
        request = JSON.parse(data)

        puts "received request"
        puts request.inspect

        if request['get_info']
          # Fetch info and send to TCP client
          # client.puts(@microwave.get_info.to_json)
          client.puts({})

        elsif command = request['command']
          # Examples:
          #   {"command":{"time":10}}
          #   {"command":{"time":5,"power":7}}
          #   {"command":"start"}

          commands = []
          if command.is_a?(String)
            commands << [command, nil]

          elsif command.is_a?(Hash)
            start = command.delete("start")

            command.each {|k, v| commands << [k, v] }

            commands << ["start", nil] if start
          end

          reset_time = true
          if command['power'] && command['time']
            reset_time = false
          end

          commands.each do |cmd|
            puts "[MW_DAEMON]: Sending command to Microwave: #{cmd.inspect}"
            @microwave.send_command(cmd, reset_time)
          end

        end
      end

      client.close
      puts "Connection closed."

    rescue Exception => ex
      puts "Error from microwave daemon!"
      p $!, *$@

      # Close TCP connection
      client.close
    end
  end
end
