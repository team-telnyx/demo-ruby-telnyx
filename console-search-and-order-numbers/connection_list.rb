# frozen_string_literal: true

require 'telnyx'
require 'dotenv/load'

def list_credential_connections
  connections = Telnyx::CredentialConnection.list(page:{number:1,size:1})
  print(connections)
end

def create_credential_connections(connection_name, user_name, password, outbound_voice_profile_id)
  begin
    Telnyx::CredentialConnection.create(
      connection_name: connection_name,
      user_name: user_name,
      password: password,
      outbound: {
        outbound_voice_profile_id: outbound_voice_profile_id
      }
    )
    rescue Exception => ex
      puts 'Error creating connection'
      puts ex
  end
end

def update_phone_number(phone_number, connection_id)
  begin
    telnyx_phone_number = Telnyx::PhoneNumber.retrieve(phone_number)
    telnyx_phone_number.connection_id = connection_id
    telnyx_phone_number.save
  rescue Exception => ex
    puts 'Error updating Phone number'
    puts ex
  end
end

def list_phone_numbers_by_connection_name(connection_name)
  filter = {
    'voice.connection_name' => { :contains => connection_name }
  }
  phone_numbers = Telnyx::PhoneNumber.list(filter: filter)
  puts(phone_numbers.data.to_json)
end


if __FILE__ == $0
  TELNYX_API_KEY=ENV.fetch('TELNYX_API_KEY')
  Telnyx.api_key = TELNYX_API_KEY
  create_credential_connections('test123', 'happy', 'world532!53', '1558091466201367939')
  list_credential_connections
  update_phone_number('+19193359476', '1584097774725498546')
  list_phone_numbers_by_connection_name('Ruby-Call-Tracking')
end
