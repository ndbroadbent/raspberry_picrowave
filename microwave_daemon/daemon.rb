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

require 'serialport'

PORT_STR = "/dev/ttyACM0"

PORT = 3141

#@microwave = MicrowaveExt.new

@microwave = SerialPort.new(PORT_STR, 9600, 8, 1, SerialPort::NONE)


def send_command_packet(cmd, param1, param2)
  @microwave.write [0x01, cmd, param1, param2, 0x17].pack('c*')

end

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
          # client.puts(@microwave.get_info.to_json)
          client.puts({})

        elsif command = request['command']
          # Examples:
          #   {"command":{"time":10}}
          #   {"command":{"time":5,"power":7}}
          #   {"command":"start"}


          if command["time"]
            time = command["time"]

            # Clear
            send_command_packet 5, 11
            sleep 0.2

            # Set cooking mode to microwave
            send_command_packet 1, 1
            sleep 0.2

            send_command_packet 2, 0, time
            sleep 0.2

            if command["power"]
              send_command_packet 4, command["power"]
              sleep 0.2
            end

            return
          end



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


            if commands[0] == 'clock'
              hour, min = commands[1].to_s.rjust(4, '0').scan(/\d\d/).map(&:to_i)
              send_command_packet(cmd, hour, min)
            end

            if commands[0] == 'clock'
              hour, min = commands[1].to_s.rjust(4, '0').scan(/\d\d/).map(&:to_i)
              send_command_packet(cmd, hour, min)
            end


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
