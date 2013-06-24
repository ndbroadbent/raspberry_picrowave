require 'socket'
require 'json'
PORT = 3141

class Microwave
  class Daemon
    class Client
      attr_accessor :info

      def initialize
        @socket = TCPSocket.new('localhost', PORT)
        @info = {}
      end

      def fetch_info
        send_request(:get_info => true)
        @info = JSON.parse(@socket.gets)
        # Symbolize keys
        @info = @info.inject({}) do |hash, (k,v)|
          hash[k.to_sym] = v
          hash
        end
      end

      def send_request(command)
        begin
          @socket.puts(command.to_json)

        rescue Exception => ex
          puts "Error from Daemon TCP connection!"
          puts ex.inspect
          # Reset socket
          connected = false
          while !connected
            begin
              @socket = TCPSocket.new('localhost', PORT)
              connected = true
            rescue
              sleep 1
            end
          end
        end
      end

      def start(time, power_level)
        command = {:time => time, :power => power_level, :start => true}
        puts "JSON command: #{command.inspect}"
        send_request(:command => command)
      end

      # Pause by pushing the 'time' button
      def pause
        puts "Pausing Microwave..."
        send_request(:command => :pause)
      end

      def stop
        puts "Stopping Microwave..."
        send_request(:command => :stop)
      end
    end
  end
end
