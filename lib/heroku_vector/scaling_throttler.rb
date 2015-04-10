module HerokuVector
  class ScalingThrottler
    MIN_SCALE_TIME_DELTA_SEC = 5 * 60 # 5 mins

    attr_accessor :last_scale_time

    def reset
      @last_scale_time = nil
    end

    def touch
      @last_scale_time = Time.now
    end

    def too_soon?
      return false unless last_scale_time
      scale_delta = Time.now - last_scale_time

      MIN_SCALE_TIME_DELTA_SEC >= scale_delta
    end
  end
end
