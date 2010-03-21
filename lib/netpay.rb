module Netpay

  require "cgi"
  require "net/http"
  require "net/https"

  DEFAULT_TIMEOUT = 3.minutes

  class Poster
    # names are the same as provided by NetPay documentation
    REQUIRED_OPTS = [:CardNum, :ExpMonth, :ExpYear, :Member, :Amount, :Currency, :CVV2, :Email, :PersonalNum, :PhoneNumber, :Comment]

    DEFAULT_OPTS = {
      :TransType => 0,
      :TypeCredit => 1,
      :Payments => 1
    }

    attr_reader :response

    def initialize(url, company_number)
      @url, @company_number = url, company_number
    end

    def post(opts)
      opts.symbolize_keys!

      missed_params = REQUIRED_OPTS - opts.keys
      raise ArgumentError.new("Missed keys: #{missed_params.join(', ')}") unless missed_params.blank?

      form_data = opts.merge(DEFAULT_OPTS).merge(:CompanyNum => @company_number)
      @response = nil

      success = false
      exception = nil
      code = nil

      uri = URI.parse(@url)
      request = Net::HTTP::Post.new(uri.path)
      request.set_form_data(form_data)

      net = Net::HTTP.new(uri.host, uri.port)
      net.use_ssl = true
      res = net.start do |http|
        http.open_timeout = DEFAULT_TIMEOUT
        http.request(request)
      end

      begin
        case res
        when Net::HTTPSuccess
          @response = res.body
          success = true
        else
          @response = res.try(:body)
        end
        code = res.code
      rescue => e
        exception = e
      end

      NetpayLog.create(:request => form_data.inspect, :response => @response, 
        :exception => exception, :netpay_status => parsed_response[:Reply], :http_code => code)

      success
    end

    def success?
      "000" == parsed_response[:Reply]
    end

    def parsed_response
      self.class.parse_response(@response) rescue {}
    end

  protected
    def self.parse_response(response_string)
      res = CGI.parse(response_string)
      res.keys.inject(HashWithIndifferentAccess.new) do |h, v|
        h[v] = res[v].is_a?(Array) && 1 == res[v].size ? res[v].first : res[v]
        h
      end
    end
  end

  class SilentPost < Poster
    def initialize(company_number)
      super("https://process.netpay-intl.com/member/remote_charge.asp", company_number)
    end

    def process(cc, expiration_month, expiration_year, name_on_card, amount_cents, ccv2, email, user_ident, phone_number, transaction_description, currency = "ILS")
      amount = sprintf("%d.%02d", amount_cents/100, amount_cents%100)
      post(:CardNum => cc, :ExpMonth => expiration_month, :ExpYear => expiration_year, 
        :Member => name_on_card, :Amount => amount, :Currency => currency, :CVV2 => ccv2,
        :Email => email, :PersonalNum => user_ident, :PhoneNumber => phone_number,
        :Comment => transaction_description)
    end
  end
end