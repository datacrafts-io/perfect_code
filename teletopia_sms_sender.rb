require 'uri'

module SmsMessages
  class Sender
    attr_reader :messages, :sender, :previous_gateway, :result

    ALPHANUMERIC_SENDER = 5

    def initialize(messages: [], sender:)
      @messages = messages
      @sender   = sender
    end

    def send
      return if messages.blank?

      send_message(gateway(type: :primary))
    end

    private

    def send_message(gateway)
      request = Typhoeus::Request.new(
        gateway,
        method:  :post,
        headers: headers,
        body:    body.to_json
      )
      request.on_complete do |response|
        @previous_gateway = gateway

        if response.success?
          return JSON.parse(response.body)
        else
          if repeat_sending?(response)
            send_message(gateway(type: :secondary))
          else
            fail RuntimeError, response.body
          end
        end
      end
      request.run
    end

    def repeat_sending?(response)
      previous_gateway != gateway(type: :secondary)
    end

    def headers
      {
        'Content-Type' => 'application/json',
        'User-Agent'   => 'Lipscore SMS Service'
      }
    end

    def body
      body = {
        auth: {
          username: SmsSenderConfig.username,
          password: SmsSenderConfig.password
        },
        messages: []
      }

      messages.each do |message|
        body[:messages] << {
          clientRef:   message[:id].to_s,
          senderType:  ALPHANUMERIC_SENDER,
          sender:      sender,
          recipient:   message[:phone],
          contentText: {
            text: message[:text]
          }
        }
      end

      body
    end

    def gateway(type: :primary)
      gateway = "gateway_#{type.to_s}"
      "#{SmsSenderConfig.gateway(gateway)}/gateway/v3/json"
    end
  end
end
