require 'faraday'
require 'faraday_middleware'
require 'json'
require 'active_support'

module Amorail
  # Amorail http client
  class Client
    attr_reader :usermail, :api_key, :api_endpoint, :custom_options

    def initialize(api_endpoint: Amorail.config.api_endpoint,
                   api_key: Amorail.config.api_key,
                   usermail: Amorail.config.usermail,
                   custom_options: {})
      @api_endpoint = api_endpoint
      @api_key = api_key
      @usermail = usermail
      @custom_options = custom_options if custom_options.any?
      @connect = Faraday.new(url: api_endpoint) do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.response :json, content_type: /\bjson$/
        faraday.use :instrumentation
      end
    end
    def properties
      @properties ||= Property.new(self)
    end

    def connect
      @connect || self.class.new
    end

    def authorize
      puts "\n\n\n\n\n authorize  authorize  authorize  authorize  authorize  authorize   \n\n\n\n"
      self.cookies = nil
      response = post(
        Amorail.config.auth_url,
        'USER_LOGIN' => usermail,
        'USER_HASH' => api_key
      )
      cookie_handler(response)
      response
    end

    def safe_request(method, url, params = {})
      send(method, url, params)
    rescue ::Amorail::AmoUnauthorizedError
      authorize
      send(method, url, params)
    end

    def get(url, params = {})
      dt = 'Tue, 27 Jun 2017 08:56:56'
      # dt = (DateTime.now.-  10.minutes).httpdate
      # dt = (DateTime.now - 10.minutes).utc
      puts "\n GEEEETT url=[#{url}] params=[#{params.to_json}] \n"
      headers = (params[:headers]) ? params.slice!(*params.keys.map { |x| (x == :headers) ? nil : x })[:headers] : nil
      puts "\n GEEEETT headers=[#{headers.to_json}] params=[#{params.to_json}] dt=[#{dt}] \n"
      response = connect.get(url, params) do |request|
        request.headers['Cookie'] = cookies if cookies.present?
        # request.env["HTTP_IF_MODIFIED_SINCE"] = dt
        # request.headers['If-Modified-Since']  = dt
        request.headers['if-modified-since']  = dt  unless (url.eql? '/private/api/v2/json/accounts/current')
        
        # request.headers['HTTP_IF_MODIFIED_SINCE'] = dt
        # request.headers['Last-Modified'] = dt
        
        # headers&.each { |k, v|
        #   puts "\n header k=[#{k}] val=[v] \n"
        #   request.headers[k.to_s] = v.to_s
        # }
        # request.headers.merge(headers) if headers
        puts "\n get_r_headers=[#{request.headers.to_json}] \n\n\n"
      end
      handle_response(response)
    end

    def post(url, params = {})     
      puts "\n POST POST url=[#{url}] params=[#{params.to_json}] \n"       
      headers = (params[:headers]) ? params.slice!(*params.keys.map { |x| (x == :headers) ? nil : x })[:headers] : nil
      puts "\n POST POST headers=[#{headers.to_json}] params=[#{params.to_json}] \n"
      # puts "\n\n\n\n\n POST  POST  POST  POST  POST  POST url=[#{url}] headers=[#{headers.to_json}]  params=[#{params.to_json}]  \n\n\n\n"      
      response = connect.post(url) do |request|
        request.headers['Cookie'] = cookies if cookies.present?
        request.headers['Content-Type'] = 'application/json'
        headers&.each { |k, v|
          puts "\n header k=[#{k}] val=[v] \n"
          request.headers[k.to_s] = v.to_s
        }
        # request.headers.merge(headers) if headers
        puts "\n post_r_headers=[#{request.headers.to_json}]\n"
        request.body = params.to_json
      end
      handle_response(response)
    end

    private

    attr_accessor :cookies

    def cookie_handler(response)
      self.cookies = response.headers['set-cookie'].split('; ')[0]
    end

    def handle_response(response) # rubocop:disable all
      return response if [200, 201, 204].include? response.status
      case response.status
      when 301
        fail ::Amorail::AmoMovedPermanentlyError
      when 400
        fail ::Amorail::AmoBadRequestError
      when 401
        fail ::Amorail::AmoUnauthorizedError
      when 403
        fail ::Amorail::AmoForbiddenError
      when 404
        fail ::Amorail::AmoNotFoundError
      when 500
        fail ::Amorail::AmoInternalError
      when 502
        fail ::Amorail::AmoBadGatewayError
      when 503
        fail ::Amorail::AmoServiceUnaviableError
      else
        fail ::Amorail::AmoUnknownError(response.body)
      end
    end
  end
end
