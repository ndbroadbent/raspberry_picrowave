require 'httparty'

class MicrowaveCookingDB
  def initialize(options)
    @email   = options[:email]
    @api_key = options[:api_key]
  end

  def find(upc)
    begin
      puts "Looking up #{upc} on microwavecookingdb.com..."
      product = HTTParty.get("http://www.microwavecookingdb.com/products/#{upc}.json", query: {email: @email, api_key: @api_key})
      return nil if product["error"]
      product
    rescue Exception => ex
      p $!, *$@
      nil
    end
  end
end
