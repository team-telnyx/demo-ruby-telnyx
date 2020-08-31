require "telnyx"
require 'dotenv/load'

def search_numbers(area_code)
  begin
    filter = {
        coutry_code: "US",
        national_destination_code: area_code,
        features:["sms", "voice", "mms"],
        limit: 2
      }
    # puts filter
    telnyx_response = Telnyx::AvailablePhoneNumber.list(filter)
    return telnyx_response
  rescue Exception => ex
    puts "Error searching numbers"
    puts ex
    exit
  end
end

def parse_results(telnyx_search_response)
  if telnyx_search_response.metadata.total_results < 1
    puts "No numbers returned"
    puts telnyx_search_response
    exit
  end
  available_number_list = telnyx_search_response.data.map do |e|
    {phone_number: e.phone_number}
  end
  # puts available_number_list
  return available_number_list
end

def order_numbers(phone_numbers)
  phone_numbers.each do |phone_number|
    begin
      puts "(y/n)? Would you like to order: #{phone_number[:phone_number]}"
      user_input = gets.chomp
      if user_input.downcase != "y"
        puts "Ok, not ordering"
      else
        puts "Ok, ordering #{phone_number[:phone_number]}"
        telnyx_response = Telnyx::NumberOrder.create(
          phone_numbers: [phone_number])
        telnyx_response.phone_numbers.each do |e|
          puts "Order is #{telnyx_response.status} for phone_number_id: #{e.id}"
        end
      end
    rescue Exception => ex
      puts "Error ordering phone numbers"
      puts ex
      exit
    end
  end
end


if __FILE__ == $0
  TELNYX_API_KEY=ENV.fetch("TELNYX_API_KEY")
  Telnyx.api_key = TELNYX_API_KEY
  puts "Where to search for numbers"
  area_code = gets.chomp
  telnyx_search_response = search_numbers(area_code)
  phone_numbers = parse_results(telnyx_search_response)
  order_numbers(phone_numbers)
end