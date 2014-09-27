require 'libdevinput'
DevInput.class_eval { attr_reader :dev }
EVIOCGRAB = 1074021776
require 'barby/barcode/ean_13'
require 'barby/barcode/upc_supplemental'

class Microwave
  class BarcodeScanner
    def initialize
      @barcode_scanner = DevInput.new(BARCODE_SCANNER_EVENT)
      # Grab barcode scanner exclusively (so keypress events aren't heard by Linux)
      @barcode_scanner.dev.ioctl(EVIOCGRAB, 1)
    end

    def valid_barcode?(barcode)
      begin
        Barby::EAN13.new(barcode[0...-1]).to_s == barcode ||
        Barby::UPCSupplemental.new(barcode[0...-1]).to_s == barcode
      rescue
        false
      end
    end

    def listen!
      puts "Ready for barcodes!"

      while true
        barcode = ''
        @barcode_scanner.each do |event|
          # Just listen for 'key presses'
          if event.type == 1 && event.value == 1
            if event.code == 28  # Enter key
              if valid_barcode?(barcode)
                yield barcode
              else
                puts "Not a UPC barcode! (#{barcode})"
              end
              barcode = ''
            else
              barcode << event.code_str
            end
          end
        end
      end
    end
  end
end