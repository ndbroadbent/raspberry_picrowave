#!/usr/bin/env ruby
require 'rubygems'
require 'chronic_duration'
require File.expand_path('../../arduino_ruby/arduino', __FILE__)

ARDUINO_DAEMON_PORT = 3141
$arduino = Microwave::Arduino.new

class Microwave
  class VoiceControl
    class << self
      def voice_command(string)
        begin
          string = string.downcase.strip
          # If command doesn't start with 'microwave',
          # prefix command with 'v', which sets the command state to 'no (v)oice keyword'
          if string =~ /^microwave /
            string.gsub!(/^microwave /, '')
            @keyword = true
          else
            @keyword = false
          end

          puts string

          if string =~ /start/
            send_command 's'

          elsif string =~ /stop/
            send_command 'S'

          else
            if total_seconds = ChronicDuration.parse(string)
              serial_command = ""

              serial_command << "t#{total_seconds};"
              if power = string[/(on )?(medium|high|low|defrost)$/, 2]
                serial_command << "pl#{power[0]}"
              end
              serial_command << "s"

              send_command serial_command
            end
          end

        rescue Exception => ex
          print "Ruby Exception: "
          puts ex.inspect
        end
      end

      private

      def send_command(command)
        if command != ""
          if @keyword
            # Choose a random affirmation
            ok_num = rand(3) + 1
            play "ok#{ok_num}.mp3"
          else
            command = ("v" << command)
          end

          puts "Sending command to microwave: #{command}"
          $arduino.serial(command)
        end
      end

      def play(file)
        puts "Playing: #{file}"
        path = File.expand_path("../../audio/#{file}", __FILE__)
        `mpg123 "#{path}" > /dev/null 2>&1`
      end
    end
  end
end