require 'httparty'

class MicrowaveCookingDB
  def self.find(upc)
    product = HTTParty.get("http://www.microwavecookingdb.com/products/#{upc}.json",
      email: Config.mwcdb.email, api_key: Config.mwcdb.api_key)

    return nil if result["error"]
    product
  end
end
