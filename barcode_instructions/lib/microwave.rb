require File.expand_path('../../../microwave_daemon/lib/client', __FILE__)
require 'microwave/barcode_scanner'
require 'microwave/cooking_step'

class Microwave
  attr_accessor :arduino, :barcode_scanner

  def initialize(preparation_steps)
    @preparation_steps = preparation_steps
    @microwave           = Daemon::Client.new
    @barcode_scanner   = BarcodeScanner.new
    @upc_queue         = Queue.new
  end

  def start_thread!(method)
    Thread.new do
      while true
        begin
          self.send(method)
        rescue Exception => ex
          puts "Error from #{method}!"
          puts ex.inspect
          sleep 2
        end
      end
    end
  end

  def fetch_arduino_info
    begin
      last_info = nil

      while true
        @microwave.fetch_info

        if last_info != @microwave.info
          puts @microwave.info.inspect
          last_info = @microwave.info
        end

        sleep 0.5
      end
    rescue Exception => ex
      # Try re-initializing arduino until connection succeeds
      @microwave = Arduino.new
      raise ex
    end
  end

  def fetch_barcodes
    @barcode_scanner.listen! do |upc|
      if @preparation_steps[upc]
        @upc_queue << upc
      else
        play "not_found.mp3" # Sorry, I don't know how to cook that!
      end
    end
  end

  def process_barcodes
    while true
      upc = @upc_queue.pop
      product = @preparation_steps[upc]

      puts "Cooking: #{product['name']}"

      steps = CookingStep.steps_for_product(product)

      # Microwave will count down total time of all steps
      time_remaining = steps.map(&:time).inject(:+)

      # If barcode was scanned while door was open, wait for door to close
      if @microwave.info[:door_open]
        puts "Waiting for microwave door to close..."
        sleep(0.5) until !@microwave.info[:door_open]
      end

      steps.each do |step|

        play step.instruction if step.instruction

        if step.wait_for_door_cycle
          return false unless wait_for_door_cycle(step)

        elsif step.time > 0
          @microwave.start(time_remaining, step.power)
          sleep 1 # Give microwave info time to refresh before checking interrupt

          puts "Waiting #{step.time} seconds..."
          ((step.time - 1) * 2).times do
            sleep 0.5
            return false if check_for_interrupt
          end

          time_remaining -= step.time

          if time_remaining > 0
            puts "Time remaining: #{time_remaining}"

            @microwave.pause
          else
            wait_for_food_to_be_taken
          end
        end
      end
    end
  end

  def wait_for_door_cycle(step)
    puts "Waiting for microwave door to open..."
    elapsed = 0
    until @microwave.info[:door_open]
      sleep(0.5)
      elapsed += 0.5

      if elapsed % 30 == 0
        play "seriously.mp3" # Seriously, what are you doing?
      end
      if elapsed % 15 == 0
        # Repeat instructions if there is a delay
        play step.instruction if step.instruction
      end

      return false if check_for_interrupt
    end

    puts "Waiting for microwave door to close..."
    elapsed = 0
    until !@microwave.info[:door_open]
      sleep(0.5)
      elapsed += 0.5

      if elapsed % 15 == 0
        play "close_the_door.mp3" # "Please close the door. I'm getting cold."
      end
      return false if check_for_interrupt
    end

    true
  end

  def wait_for_food_to_be_taken
    play "ready1.mp3"

    puts "Waiting for microwave door to open..."
    elapsed = 0
    stage = 2
    until @microwave.info[:door_open]
      sleep(0.5)
      elapsed += 0.5

      if elapsed == 25
        play "ready#{stage}.mp3"
        stage += 1
        stage = 2 if stage > 4
        elapsed = 0
      end
    end
  end

  def check_for_interrupt
    if !@upc_queue.empty?
      play "busy.mp3" # I'm busy! Please don't scan any more bar-codes.

      # Clear barcodes queue and keep the current program going.
      @upc_queue.clear
      return false
    end

    # Interrupt the current cooking program if the microwave is off and not paused.
    if !@microwave.info[:on] && !@microwave.info[:paused]
      puts "Aborting cooking program! The microwave has been stopped."
      return true
    end
  end

  def play(file)
    puts "Playing: #{file}"
    path = File.expand_path("../../../audio/#{file}", __FILE__)
    `mpg123 "#{path}" > /dev/null 2>&1`
  end
end
