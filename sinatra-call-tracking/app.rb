require 'sinatra'
require 'telnyx'
require 'sinatra/namespace'
require 'dotenv/load'

if __FILE__ == $0
  TELNYX_API_KEY = ENV.fetch("TELNYX_API_KEY")
  TELNYX_APP_PORT = ENV.fetch("PORT")
  TELNYX_CONNECTION_ID = ENV.fetch("TELNYX_CALL_CONTROL_APP_ID")
  TELNYX_CONNECTION_NAME = ENV.fetch("TELNYX_CALL_CONTROL_APP_NAME")
  Telnyx.api_key = TELNYX_API_KEY
  DATABASE = Hash.new
  set :port, TELNYX_APP_PORT
end

get '/' do
  "Hello World"
end

namespace '/phone-numbers' do
  before do
    content_type 'application/json'
  end

  def search_numbers(area_code)
    begin
      filter = {
        country_code: "US",
        national_destination_code: area_code,
        features: ["sms", "voice", "mms"],
        limit: 1
      }
      telnyx_response = Telnyx::AvailablePhoneNumber.list(filter)
      available_number_list = telnyx_response.data.map do |e|
        { phone_number: e.phone_number }
      end
      return available_number_list
    rescue Exception => ex
      puts "Error searching numbers"
      puts ex
    end
  end

  def order_numbers(phone_numbers)
    begin
      telnyx_response = Telnyx::NumberOrder.create(
        phone_numbers: phone_numbers,
        connection_id: TELNYX_CONNECTION_ID
      )
      while telnyx_response.status == 'pending'
        telnyx_response = Telnyx::NumberOrder.retrieve(telnyx_response.id)
        sleep(0.25)
      end
      return telnyx_response
    rescue Exception => ex
      puts "Error ordering phone numbers"
      puts ex
    end
  end

  def update_forwarding_numbers(phone_numbers, forward_number)
    begin
      phone_numbers.each do |element|
        telnyx_number = Telnyx::PhoneNumber.retrieve(element[:phone_number])
        telnyx_number.tags = [forward_number]
        telnyx_number.save
      end
    rescue Exception => ex
      puts "Error Updating Phone numbers"
      puts ex
    end
  end

  post '' do
    body = JSON.parse(request.body.read)
    available_number_list = search_numbers(body['area_code'])
    order_numbers(available_number_list)
    update_forwarding_numbers(available_number_list, body['forward_number'])
    return available_number_list.to_json
  end

  get '' do
    filter = {
      'voice.connection_name' => { :contains => TELNYX_CONNECTION_NAME }
    }
    phone_numbers = Telnyx::PhoneNumber.list(filter: filter)
    phone_numbers.data.to_json
  end
end

namespace '/calls' do

  before do
    content_type 'application/json'
  end

  get '' do
    DATABASE.to_json
  end
end

namespace '/call-control' do

  post '/inbound' do
    body = JSON.parse(request.body.read)
    from = body['data']['payload']['from']
    to = body['data']['payload']['to']
    event_type = body['data']['event_type']
    outbound_webhook_url = URI::HTTP.build(host: request.host, path: '/call-control/outbound')
    call = Telnyx::Call.new id: body['data']['payload']['call_control_id'],
                            call_leg_id: body['data']['payload']['call_leg_id']
    if event_type == 'call.initiated'
      begin
        call.answer
      rescue Exception => ex
        puts "Error answering inbound call"
        puts ex
      end
    elsif event_type == 'call.answered'
      begin
        call_count = DATABASE.key?(to) ? DATABASE[to] : 0
        telnyx_number = Telnyx::PhoneNumber.retrieve(to)
        forward_number = telnyx_number.tags.first
        transfer_payload = {
          webhook_url: outbound_webhook_url,
          to: forward_number
        }
        call.transfer(transfer_payload)
        DATABASE[to] = call_count + 1
      rescue Exception => ex
        puts "Error transferring inbound call"
        puts ex
      end
    else
      puts(event_type)
    end
    return 'ok'
  end

  post '/outbound' do
    body = JSON.parse(request.body.read)
    puts(body)
    return 'ok'
  end
end
