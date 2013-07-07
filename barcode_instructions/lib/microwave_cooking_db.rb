require 'httparty'

class MicrowaveCookingDB
  def initialize(options)
    @email   = options[:email]
    @api_key = options[:api_key]
  end

  def find(upc)
    product = HTTParty.get("http://www.microwavecookingdb.com/products/#{upc}.json", email: @email, api_key: @api_key)

    return nil if product["error"]
    product
  end
end
