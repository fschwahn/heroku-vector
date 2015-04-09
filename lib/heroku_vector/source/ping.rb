module HerokuVector::Source
  class Ping
    def initialize(options={})
      options[:ping_url] ||= HerokuVector.ping_url

      @ping_url = options[:ping_url]
    end

    def timeouts
      uri = URI.parse(@ping_url)
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        0
      else
        1
      end
    end
    alias_method :sample, :timeouts

    def unit
      'timeouts'
    end

  end
end
