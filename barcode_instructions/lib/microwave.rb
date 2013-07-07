require File.expand_path('../../../microwave_daemon/lib/client', __FILE__)
require 'microwave/barcode_scanner'
require 'microwave/cooking_step'

class Microwave
  TWEET_PREFIXES = [
    "Just finished cooking up some",
    "Just cooked some",
    "Just finished cooking some",
    "Just heated up some",
    "Finished cooking"
  ]

  TWEET_SUFFIXES = [
    "I bet it tastes pretty good!",
    "I would totally eat it if I had a mouth.",
    "I'm pretty sure it tastes like chicken. Or maybe tasty wheat.",
    "I hope they like it!",
    "I cooked it with my microwaves.",
    "Mmmmmm, tastes like 2.45 GHz non-ionizing radiation.",
    ""
  ]

  attr_accessor :arduino, :barcode_scanner

  def initialize
    @microwave         = Daemon::Client.new
    @barcode_scanner   = BarcodeScanner.new
    @product_queue     = Queue.new

    @mwcdb_client = MicrowaveCookingDB.new(email: Config.mwcdb.email, api_key: Config.mwcdb.api_key)
  end

  def start_thread!(method)
    Thread.new do
      while true
        begin
          self.send(method)
        rescue Exception => ex
          puts "Error from #{method}!"
          p $!, *$@
          sleep 2
        end
      end
    end
  end

  def fetch_microwave_info
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
      # Try re-initializing until connection succeeds
      @microwave = Daemon::Client.new
      raise ex
    end
  end

  def fetch_barcodes
    @barcode_scanner.listen! do |upc|
      product = @mwcdb_client.find(upc)
      if product
        @product_queue << product
      else
        save_unknown_upc_for_sinatra(upc)
        play "not_found" # Sorry, I don't know how to cook that!
      end
    end
  end

  def process_barcodes
    while true
      product = @product_queue.pop

      require 'debugger'
      debugger

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
            # Finished!
            Twitter.update("#{TWEET_PREFIXES.sample} #{product["name"]}! #{TWEET_SUFFIXES.sample}")

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
        play "seriously" # Seriously, what are you doing?
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
        play "close_the_door" # "Please close the door. I'm getting cold."
      end
      return false if check_for_interrupt
    end

    true
  end

  def wait_for_food_to_be_taken
    play "ready1"

    puts "Waiting for microwave door to open..."
    elapsed = 0
    stage = 2
    until @microwave.info[:door_open]
      sleep(0.5)
      elapsed += 0.5

      if elapsed == 25
        play "ready#{stage}"
        stage += 1
        stage = 2 if stage > 4
        elapsed = 0
      end
    end
  end

  def check_for_interrupt
    if !@product_queue.empty?
      play "busy" # I'm busy! Please don't scan any more bar-codes.

      # Clear product_queue and keep the current program going.
      @product_queue.clear
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
    path = File.expand_path("../../../audio/#{file}.mp3", __FILE__)
    `mpg123 "#{path}" > /dev/null 2>&1`
  end

  SINATRA_BARCODES_FILE = File.expand_path("../../../sinatra_app/unknown_barcodes.yml", __FILE__)

  # Save the last 10 unique unknown upc barcodes to display in the Sinatra app
  def save_unknown_upc_for_sinatra(upc)
    if File.exists?(unknown_barcodes_file)
      unknown_barcodes = YAML.load_file(SINATRA_BARCODES_FILE)
    else
      unknown_barcodes = []
    end

    unknown_barcodes << upc

    File.open(unknown_barcodes_file, 'w') do |f|
      f.puts unknown_barcodes.uniq[0,10].to_yaml
    end
  end
end
