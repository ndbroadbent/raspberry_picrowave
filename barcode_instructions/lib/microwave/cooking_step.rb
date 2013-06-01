class Microwave
  class CookingStep
    attr_accessor :time, :power, :instruction, :wait_for_door_cycle

    def initialize(step)
      @time = 0
      @power = 'off'

      if step.is_a?(Hash)
        @power = step['power'] if step['power']
        @time  = step['time']  if step['time']

        if step['stand']
          @time, @power = step['stand'], 'off'
        end

      elsif step == "stir"
        @instruction = "stir.mp3"  # Please open the microwave door and stir the food.
        @wait_for_door_cycle = true
      end
    end

    def self.steps_for_product(product)
      product['steps'].map do |step_params|
        CookingStep.new(step_params)
      end
    end
  end
end
