require 'eventmachine'

module HerokuVector
  class Worker
    include HerokuVector::Helper

    attr_accessor :options, :dyno_scalers, :engine, :scaling_throttlers

    def initialize(options={})
      @options = options
      @dyno_scalers = []
      @scaling_throttlers = {}
    end

    def run
      if options[:config]
        if File.exist?(options[:config])
          logger.info "Loading config from '#{options[:config]}'"
          load options[:config]
        else
          logger.fatal "No config found at '#{options[:config]}'"
          logger.info "You can copy config.rb.example => config.rb to get started"
          logger.info "OR run heroku_vector -c /path/to/your/config.rb"
          logger.info "Just Starting? Test your Source config with sampler mode: heroku_vector -s"
          exit 1
        end
      end

      load_dyno_scalers

      EM.run do
        dyno_scalers.each do |scaler|
          EM::PeriodicTimer.new(scaler.period) do
            scaler.run
          end
        end
      end
    end

    def load_dyno_scalers
      HerokuVector.dyno_scalers.each do |options|
        name = options.delete(:name)
        logger.info "Loading Scaler: #{name}, #{options.inspect}"

        @scaling_throttlers[name] ||= ScalingThrottler.new
        @dyno_scalers << DynoScaler.new(name, options.merge(scaling_throttler: @scaling_throttlers[name]))
      end
    end

  end
end
