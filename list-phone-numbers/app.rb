require "telnyx"
require 'dotenv/load'

def list_all_numbers()
  begin
    page_number = 1
    page_size = 250
    phone_number_response = list_numbers(page_number,page_size)
    current_page = phone_number_response.meta.page_number
    total_pages = phone_number_response.meta.total_pages
    phone_number_list = phone_number_response.data
    while current_page < total_pages
      page_number = page_number + 1
      phone_number_response = list_numbers(page_number,page_size)
      current_page = phone_number_response.meta.page_number
      total_pages = phone_number_response.meta.total_pages
      phone_number_list.push(*phone_number_response.data)
    end
    return phone_number_list
  rescue Exception => ex
    puts "Exception listing numbers"
    puts ex
    exit
  end
end

def list_numbers(page_number, size)
  begin
    page = {
      number: page_number,
      size: size
    }
    phone_numbers = Telnyx::PhoneNumber.list(page: page)
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
  numbers = list_all_numbers()
  numbers_with_voice = list_numbers_with_voice(numbers);
  # puts(numbers_with_voice.length)
  numbers_with_messaging = list_numbers_with_messaging(numbers);
  # puts(numbers_with_messaging.length)
end