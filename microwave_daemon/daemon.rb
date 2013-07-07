#!/usr/bin/env ruby
#
# Allows multiple programs to communicate with the Arduino
#
require 'rubygems'
require 'socket'
require 'thread'
require 'json'
require File.expand_path('../lib/audio_player', __FILE__)
require File.expand_path('../microwave', __FILE__)

PORT = 3141

@microwave = MicrowaveExt.new
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

        if request['get_info']
          # Fetch info and send to TCP client
          client.puts(@microwave.get_info.to_json)

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

          commands.each do |cmd|
            puts "Sending command to Microwave: #{cmd.inspect}"

            # Tell microwave that this came from a random voice.
            # (prevents actions when people are just talking in kitchen)
            cmd << true if request['latent_voice']

            @microwave.send_command(*cmd)
          end
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
