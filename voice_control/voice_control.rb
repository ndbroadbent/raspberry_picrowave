#!/usr/bin/env ruby
require 'rubygems'
require 'chronic_duration'
require File.expand_path('../../microwave_daemon/lib/client', __FILE__)

ARDUINO_DAEMON_PORT = 3141
$microwave = Microwave::Daemon::Client.new

class Microwave
  class VoiceControl
    class << self
      def voice_command(string)
        begin
          string = string.downcase.strip
          # If command starts with 'microwave' keyword, play an affirmative response.
          # Otherwise, notify microwave that command was sent via latent voice recognition.
          if string =~ /^microwave /
            string.gsub!(/^microwave /, '')
            @keyword = true
          else
            @keyword = false
          end

          if string =~ /start/
            send_command 'start'

          elsif string =~ /stop/
            send_command 'stop'

          else
            if total_seconds = ChronicDuration.parse(string)
              command = {:time => total_seconds, :power => 'high', :start => true}

              if power = string[/(on )?(medium|high|low|defrost)$/, 2]
                command[:power] = power
              end

              send_command(command)
            end
          end

        rescue Exception => ex
          puts "Ruby Exception: "
          p $!, *$@
        end
      end

      private

      def send_command(command)
        request = {:command => command}

        if @keyword
          # Choose a random affirmation
          ok_num = rand(3) + 1
          play "ok#{ok_num}.mp3"

        else
          request[:latent_voice] = true
        end

        puts "Sending command to microwave: #{request.inspect}"

        $microwave.send_request(request)
      end

      def play(file)
        puts "Playing: #{file}"
        path = File.expand_path("../../audio/#{file}", __FILE__)
        `mpg123 "#{path}" > /dev/null 2>&1`
      end
    end
  end
end