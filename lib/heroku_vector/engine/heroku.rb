require 'heroku-api'

module HerokuVector::Engine
  class Heroku
    include HerokuVector::Helper

    CacheEntry = Struct.new(:data, :expires_at)

    attr_accessor :app, :heroku

    def initialize(options={})
      @app = options[:app] || HerokuVector.heroku_app_name
      @heroku = options[:heroku] || ::Heroku::API.new
    end

    def count_for_dyno_name(dyno_name)
      dynos_for_type(dyno_name).size
    end

    def scale_dynos(dyno_name, count)
      expire_dyno_cache
      current_count = count_for_dyno_name(dyno_name)
      if count > current_count
        scale_dynos_up(dyno_name, count)
      elsif count < current_count
        scale_dynos_down(dyno_name, count, current_count)
      end
    end

    private
      # Cache dynos for 1 minute to prevent Heroku API from reaching the rate limit
      def dynos
        return @dynos.data if @dynos && @dynos.expires_at > Time.now
        @dynos = CacheEntry.new(get_dynos_from_api, Time.now + 60)
        @dynos.data
      end

      def expire_dyno_cache
        @dynos = nil
      end

      def get_dynos_from_api
        run_heroku_api_command(:get_ps, app)
      end

      def dynos_for_type(type)
        dynos.select { |d| d['process'].start_with?(type) }
      end

      def scale_dynos_up(dyno_name, count)
        run_heroku_api_command(:post_ps_scale, app, dyno_name, count)
        logger.info "Scaling #{dyno_name} dynos up to #{count}"
      end

      # Handle scaling dynos down as a special case so always the oldest dyno will be killed
      def scale_dynos_down(dyno_name, count, current_count)
         dynos_for_type(dyno_name).sort_by { |d| d['elapsed'] }.reverse.take(current_count - count).each do |dyno|
          run_heroku_api_command(:post_ps_stop, app, { 'ps' => dyno['process'] })
         end
      end

      def run_heroku_api_command(command, *args)
        response = heroku.send(command, *args)
        assert_heroku_api_success(response)
        logger.debug "Heroku.#{command}(#{args.join(', ')})"

        response.body
      rescue => e
        logger.warn "Calling Heroku API failed for command: Heroku.#{command}(#{args.join(', ')}): #{e}"
        nil
      end

      def assert_heroku_api_success(response)
        raise 'Invalid Heroku API Response' unless response
        raise "Error #{response.status} from Heroku API" unless response.status == 200
      end
  end
end
