require 'libdevinput'
require 'barby/barcode/ean_13'

class Microwave
  class BarcodeScanner
    def initialize
      @barcode_scanner = DevInput.new(BARCODE_SCANNER_EVENT)
    end

    def valid_barcode?(barcode)
      begin
        Barby::EAN13.new(barcode[0...-1]).to_s == barcode
      rescue
        false
      end
    end

    def listen!
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