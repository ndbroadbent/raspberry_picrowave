require 'serialport'

class SerialMicrowave
  PORT_STR = "/dev/ttyACM0"

  CMD_CLOCK = 0
  CMD_MODE = 1
  CMD_TIME = 5
  CMD_POWER = 4

  POWER_LEVELS = {
    'high' => 10,
    'medium' => 7,
    'low' => 5,
    'defrost' => 3
  }

  WEB_BUTTON_MAPPINGS = {
    "Quickstart Medium 2m"      => [['time', 120], ['power', 'medium']],
    "Quickstart High 10s"       => [['time', 10], ['power', 'high']],
    "Quickstart High 20s"       => [['time', 20], ['power', 'high']],
    "Quickstart High 30s"       => [['time', 30], ['power', 'high']],
    "Quickstart High 1m"        => [['time', 60], ['power', 'high']],
    "Quickstart High 2m"        => [['time', 120], ['power', 'high']],
    "Quickstart Medium 10s"     => [['time', 10], ['power', 'medium']],
    "Quickstart Medium 20s"     => [['time', 20], ['power', 'medium']],
    "Quickstart Medium 30s"     => [['time', 30], ['power', 'medium']],
    "Quickstart Medium 1m"      => [['time', 60], ['power', 'medium']],
    "Start"                     => [['button', 'start']],
    "Stop"                      => [['button', 'stop']],
    "Time 10s"                  => [['time', 120]],
    "Time 10m"                  => [['time', 120]],
    "Power Medium"              => [['time', 120]],
    "Power Defrost"             => [['time', 120]],
    "Time 1s"                   => [['time', 120]],
    "Time 1m"                   => [['time', 120]],
    "Power High"                => [['time', 120]],
    "Power Low"                 => [['time', 120]]
  }

  def initialize
    unless ENV['DEBUGGING']
      @serial = SerialPort.new(PORT_STR, 9600, 8, 1, SerialPort::NONE)
    end
  end


  def send_command(command, reset_time = true)
    case command[0]
    when 'clock'
      hour, min = command[1].to_s.rjust(4, '0').scan(/\d\d/).map(&:to_i)
      send_command_packet(0, hour, min)

    when 'time'
      send_clear
      set_microwave
      send_time command[1].to_i
      @time = command[1].to_i


    when 'power'
      if reset_time
        send_command(['time', @time || 15])
        sleep 0.2
      end

      level = POWER_LEVELS[command[1].to_s] || 10
      send_power level

      sleep 0.2

    when 'new_button'
      puts 'new button!'
      puts command[1].inspect

      if web_commands = WEB_BUTTON_MAPPINGS[command[1]]
        web_commands.each do |cmd|
          send_command cmd, false
        end
      end
    end
  end


  private

  def send_command_packet(cmd, param1, param2 = 0)
    puts "sending cmd: [#{cmd}, #{param1}, #{param2}]"

    unless ENV['DEBUGGING']
      @serial.write [0x01, cmd, param1, param2, 0x17].pack('c*')
    end

    sleep 0.3
  end

  def send_clear
    send_command_packet 5, 11
  end

  def send_time(time)
    send_command_packet 2, 0, time
  end

  def send_power(power)
    send_command_packet 4, power
  end

  def set_microwave
    send_command_packet 1, 1
  end
end
