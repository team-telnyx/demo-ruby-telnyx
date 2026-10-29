require 'telnyx'
require 'dotenv/load'
require 'json'
require 'time'
require 'timeout'
require 'websocket-client-simple'

# Mints a WebRTC login token for a telephony credential on this machine, with
# TelephonyCredential#to_jwt, instead of asking the API for one per login.
# Then, optionally, proves the token works by logging in to the WebRTC gateway.

def credential(connection_id, credential_id)
  if credential_id && !credential_id.empty?
    puts "Reusing credential #{credential_id}"
    return Telnyx::TelephonyCredential.retrieve(credential_id)
  end

  puts "Creating a credential on connection #{connection_id}"
  # include: "token_material" asks the API for the signing material to_jwt needs; it is as
  # sensitive as the SIP password, so the API returns it only on request.
  Telnyx::TelephonyCredential.create(connection_id: connection_id, name: "to_jwt demo #{Time.now.utc.iso8601}",
                                     include: "token_material")
end

# Sends a JSON-RPC login with the token and waits for the gateway's answer.
def login_check(rtc_url, token)
  answer = Queue.new
  ws = WebSocket::Client::Simple.connect(rtc_url)

  ws.on :open do
    ws.send({ jsonrpc: '2.0', id: 1, method: 'login',
              params: { login_token: token, userVariables: {}, loginParams: {} } }.to_json)
  end
  ws.on :message do |msg|
    reply = JSON.parse(msg.data) rescue next
    answer << reply if reply['id'] == 1
  end
  ws.on :error do |e|
    answer << { 'error' => { 'message' => e.message } }
  end

  reply = Timeout.timeout(15) { answer.pop }
  ws.close
  reply
end

if __FILE__ == $PROGRAM_NAME
  Telnyx.api_key = ENV.fetch('TELNYX_API_KEY')
  Telnyx.api_base = ENV['TELNYX_API_BASE'] unless ENV['TELNYX_API_BASE'].to_s.empty?

  cred = credential(ENV.fetch('TELNYX_CONNECTION_ID'), ENV['TELNYX_CREDENTIAL_ID'])
  puts "Credential #{cred.id} (#{cred.sip_username})"

  # A credential from `create` carries its token_material, so this is a pure
  # local computation. A retrieved credential fetches the material once.
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  token = cred.to_jwt(ttl: 3600)
  elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  puts "Minted a login token in #{elapsed_ms} ms (valid for 1 hour):"
  puts token

  rtc_url = ENV['TELNYX_RTC_URL'].to_s.empty? ? 'wss://rtc.telnyx.com' : ENV['TELNYX_RTC_URL']
  puts "Logging in to #{rtc_url} with it..."
  # A credential created a moment ago takes a few seconds to reach the
  # gateways; until then the login answers "Login Incorrect" (-32001).
  reply = nil
  5.times do |attempt|
    reply = login_check(rtc_url, token)
    break if reply['result'] || reply.dig('error', 'code') != -32_001
    puts "  not known to the gateway yet, retrying (#{attempt + 1}/5)..."
    sleep 3
  end
  if reply['result']
    puts "Logged in: #{reply['result']['message']}"
  else
    puts "Login failed: #{reply['error'].inspect}"
    exit 1
  end
end
