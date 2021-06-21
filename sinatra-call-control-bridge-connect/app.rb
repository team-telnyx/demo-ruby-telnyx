require 'sinatra'
require 'telnyx'
require 'dotenv/load'

Telnyx.api_key = ENV['TELNYX_API_KEY']
TELNYX_CALL_CONTROL_APP_ID = ENV['TELNYX_CALL_CONTROL_APP_ID']

set :port, ENV['TENYX_APP_PORT']

list_of_numbers_to_dial_out = [
  '+15555555555'
]

# An oversimplification of managed state, do not use `bridged_calls` or `dial_outs` globals in a production context! :)

# == Examples:
#    bridged_calls[INBOUND_CALL_CONTROL_ID] #=> OUTBOUND_CALL_CONTROL_ID
#    bridged_calls[UNBRIDGED_INBOUND_CALL_CONTROL_ID] #=> nil
bridged_calls = Hash.new

# == Examples:
#    dial_outs[INBOUND_CALL_CONTROL_ID] #=> [OUTBOUND_CALL_CONTROL_ID_1, OUTBOUND_CALL_CONTROL_ID_2, ...]
dial_outs = Hash.new([])

post '/call-control/inbound' do
  body = JSON.parse request.body.read
  event_type = body['data']['event_type']

  if event_type == 'call.initiated'
    # answer inbound call
    call = Telnyx::Call.new
    call.id = call_control_id = body['data']['payload']['call_control_id']
    call.answer
    call.playback_start(audio_url: 'https://telnyx-mms-demo.s3.us-east-2.amazonaws.com/audio_clips/ring.mp3')

    # dial out to reps, receive webhooks for dialed out calls at new endpoint
    outbound_webhook = body['meta']['delivered_to'].gsub('/call-control/inbound', "/call-control/outbound/#{call_control_id}")
    call_control_app_number = body['data']['payload']['to']

    outbound_call_control_ids = list_of_numbers_to_dial_out.map do |number|
      begin
        outbound_call = Telnyx::Call.create(
          connection_id: TELNYX_CALL_CONTROL_APP_ID,
          to: number,
          from: call_control_app_number,
          webhook_url: outbound_webhook
        )
        outbound_call.id
      rescue
        nil
      end
    end

    # store call control ids of outbound calls for later use
    dial_outs[call_control_id] = outbound_call_control_ids.compact
  end

  status :ok
end

post '/call-control/outbound/:inbound_call_control_id' do
  body = JSON.parse(request.body.read)
  event_type = body['data']['event_type']
  inbound_call_control_id = params['inbound_call_control_id']
  outbound_call_control_id = body['data']['payload']['call_control_id']
  outbound_call = Telnyx::Call.new(id: outbound_call_control_id)

  if !bridged_calls[inbound_call_control_id]
    if event_type == 'call.answered'
      outbound_call.gather_using_speak(
        payload: 'Press 1 to be connected to the client, press any other key to hang up',
        maximum_digits: 1,
        language: 'en-US',
        voice: 'female'
      )
    elsif event_type == 'call.gather.ended'
      if body['data']['payload']['digits'] == '1'
        # mark as bridged before actually attempting bridge call to mitigate potential for race conditions
        bridged_calls[inbound_call_control_id] = outbound_call_control_id

        # bridge the call
        begin
          outbound_call.bridge(call_control_id: inbound_call_control_id)
        end

        # hang up all other outbound calls
        (dial_outs[inbound_call_control_id] - [outbound_call_control_id]).each do |non_bridged_outbound_call_control_id|
          non_bridged_outbound_call = Telnyx::Call.new(id: non_bridged_outbound_call_control_id)
          # `command_id` safeguard to ensure single hangup event with API (outbound call may have already hung up)
          non_bridged_outbound_call.hangup(command_id: inbound_call_control_id)
        end
      else
        outbound_call.hangup(command_id: inbound_call_control_id)
      end
    end
  end

  status :ok
end
