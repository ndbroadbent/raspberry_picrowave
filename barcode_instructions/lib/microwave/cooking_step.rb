class Microwave
  class CookingStep
    attr_accessor :time, :power, :instruction, :wait_for_door_cycle

    def initialize(step)
      @time = 0
      @power = 'off'

      case step["action"]
      when "Cook"
        @power = step['power'] if step['power']
        @time  = step['time']  if step['time']

      when "Stand"
        @time  = step['time']  if step['time']

      when "Stir"
        @instruction = "stir"  # Please open the microwave door and stir the food.
        @wait_for_door_cycle = true
      end
    end

    def self.steps_for_product(product)
      product['steps'].map do |step_params|
        new(step_params)
      end
    end
  end
end
