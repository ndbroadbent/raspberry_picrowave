require 'httparty'

class MicrowaveCookingDB
  def initialize(options)
    @email   = options[:email]
    @api_key = options[:api_key]
    @power = options[:power]
  end

  def find(upc)
    puts "Looking up #{upc} on microwavecookingdb.com..."

    # Retry failed request 3 times
    3.times do
      begin
        product = HTTParty.get("http://www.microwavecookingdb.com/products/#{upc}.json",
          query: {email: @email, api_key: @api_key, power: @power})
        return nil if product["error"]
        return product
      rescue Exception => ex
        p $!, *$@
        nil
      end
    end
  end
end
