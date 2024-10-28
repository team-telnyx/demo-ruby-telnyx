require 'sinatra'
require 'json'
require 'dotenv/load'
require 'faye/websocket'
require 'eventmachine'
require 'base64'

set :server, 'thin' # Use Thin server to support WebSockets

# Load environment variables
OPENAI_API_KEY = ENV['OPENAI_API_KEY']
if !OPENAI_API_KEY
  puts 'Missing OpenAI API key. Please set it in the .env file.'
  exit 1
end

# Constants
SYSTEM_MESSAGE = 'You are a helpful and bubbly AI assistant who loves to chat about anything the user is interested about and is prepared to offer them facts.'
VOICE = 'alloy'
PORT = ENV['PORT'] ? ENV['PORT'].to_i : 8000

# List of Event Types to log to the console
LOG_EVENT_TYPES = [
  'response.content.done',
  'rate_limits.updated',
  'response.done',
  'input_audio_buffer.committed',
  'input_audio_buffer.speech_stopped',
  'input_audio_buffer.speech_started',
  'session.created'
]

# Root route
get '/' do
  content_type :json
  { message: "Telnyx Media Stream Server is running!" }.to_json
end

# /inbound route
post '/inbound' do
  puts "Incoming call received"
  texml_path = File.join(File.dirname(__FILE__), 'texml.xml')
  if File.exist?(texml_path)
    texml_response = File.read(texml_path)
    texml_response.gsub!("{host}", request.host)
    puts "TeXML Response: #{texml_response}"
    content_type 'text/xml'
    texml_response
  else
    puts "File not found at: #{texml_path}"
    halt 500, "TeXML file not found"
  end
end

# /media-stream route
get '/media-stream' do
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)
    puts "Client connected"

    ws.on :open do |_event|
      puts "WebSocket connection opened"

      # Connect to OpenAI WebSocket
      openai_ws = Faye::WebSocket::Client.new(
        'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01',
        nil,
        headers: {
          'Authorization' => "Bearer #{OPENAI_API_KEY}",
          'OpenAI-Beta' => 'realtime=v1'
        }
      )

      # Send session update after a short delay
      EM.add_timer(0.25) do
        session_update = {
          type: 'session.update',
          session: {
            turn_detection: { type: 'server_vad' },
            input_audio_format: 'g711_ulaw',
            output_audio_format: 'g711_ulaw',
            voice: VOICE,
            instructions: SYSTEM_MESSAGE,
            modalities: ['text', 'audio'],
            temperature: 0.8
          }
        }
        puts "Sending session update: #{session_update.to_json}"
        openai_ws.send(session_update.to_json)
      end

      # Handler for messages from OpenAI WebSocket
      openai_ws.on :message do |event|
        begin
          response = JSON.parse(event.data)
          if LOG_EVENT_TYPES.include?(response['type'])
            puts "Received event: #{response['type']} #{response}"
          end
          if response['type'] == 'session.updated'
            puts "Session updated successfully: #{response}"
          end
          if response['type'] == 'response.audio.delta' && response['delta']
            audio_delta = {
              event: 'media',
              media: {
                payload: response['delta']
              }
            }
            ws.send(audio_delta.to_json)
          end
        rescue => e
          puts "Error processing OpenAI message: #{e}, Raw message: #{event.data}"
        end
      end

      openai_ws.on :close do |_event|
        puts "OpenAI WebSocket closed"
        openai_ws = nil
      end

      openai_ws.on :error do |event|
        puts "OpenAI WebSocket error: #{event.message}"
      end

      # Handler for messages from Telnyx client WebSocket (ws)
      ws.on :message do |event|
        begin
          message = JSON.parse(event.data)
          event_type = message['event']
          if event_type == 'media'
            if openai_ws
              base64_audio = message['media']['payload']
              audio_append = {
                type: 'input_audio_buffer.append',
                audio: base64_audio
              }
              openai_ws.send(audio_append.to_json)
            end
          elsif event_type == 'start'
            stream_sid = message['stream_id']
            puts "Incoming stream has started: #{stream_sid}"
          else
            puts "Received non-media event: #{event_type}"
          end
        rescue => e
          puts "Error processing Telnyx message: #{e}, Raw message: #{event.data}"
        end
      end

      ws.on :close do |_event|
        puts "Client disconnected"
        ws = nil
        openai_ws.close if openai_ws
      end

      ws.on :error do |event|
        puts "WebSocket error: #{event.message}"
      end
    end

    # Return async Rack response
    ws.rack_response

  else
    # Not a WebSocket request
    status 400
    body "Not a WebSocket request"
  end
end

# Start the Sinatra server
set :port, PORT
