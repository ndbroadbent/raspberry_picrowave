require 'socket'

class Microwave
  class Arduino
    attr_accessor :info

    def initialize
      @socket = TCPSocket.new('localhost', ARDUINO_DAEMON_PORT)
      @info = {}
    end

    def fetch_info
      @socket.puts 'info'
      on, paused, door_open, power, time = @socket.gets.split(';')
      @info = {
        :on        => on        == '1',
        :paused    => paused    == '1',
        :door_open => door_open == '1',
        :power     => power.to_i,
        :time      => time.to_i
      }
    end

    def serial(command)
      begin
        @socket.puts "serial: #{command}"

      rescue Exception => ex
        puts "Error from Arduino TCP connection!"
        puts ex.inspect
        # Reset socket
        connected = false
        while !connected
          begin
            @socket = TCPSocket.new('localhost', ARDUINO_DAEMON_PORT)
            connected = true
          rescue
            sleep 1
          end
        end
      end
    end

    def start(time, power_level)
      command = "St#{time};pl#{power_level}s"
      puts "Serial command: #{command}"
      serial(command)
    end

    # Pause by pushing the 'time' button
    def pause
      puts "Pausing microwave with time button (sending 'P' command)..."
      serial('P')
    end

    def stop
      serial('S')
    end
  end
end
