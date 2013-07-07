class AudioPlayer
  class << self
    def button;   play "button"; end
    def start;    play "start"; end
    def stop;     play "stop"; end
    def finished; play "finished"; end

    private

    def play(file)
      path = File.expand_path("../../../audio/#{file}.mp3", __FILE__)
      if File.exist?(path)
        `mpg123 "#{path}" > /dev/null 2>&1`
      else
        puts "Error! Sound does not exist: #{path}"
      end
    end
  end
end
