require "telnyx"
require 'dotenv/load'

def list_numbers()
  begin
    (Telnyx::PhoneNumber.list()).data
  rescue Exception => ex
    puts "Exception listing numbers"
    puts ex
    exit
  end
end

def list_numbers_with_voice(numbers)
  numbers.select{|number|!number.connection_id.to_s.strip.empty?}
end

def list_numbers_with_messaging(numbers)
  numbers.select{|number|!number.messaging_profile_id.to_s.strip.empty?}
end

if __FILE__ == $0
  TELNYX_API_KEY=ENV.fetch('TELNYX_API_KEY')
  Telnyx.api_key = TELNYX_API_KEY
  numbers = list_numbers()
  numbers_with_voice = list_numbers_with_voice(numbers);
  numbers_with_messaging = list_numbers_with_messaging(numbers);
end