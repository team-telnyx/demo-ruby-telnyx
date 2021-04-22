require 'telnyx'
require 'dotenv/load'

# sends verification code to designated number
def send_verify(telnyx_verify_id)
  begin
    # input phone number (MUST BE IN E164)
    puts 'Number to Verify?'
    phone_number = gets.chomp
    # verification object
    verification = {
      phone_number: phone_number,
      type: 'sms',
      verify_profile_id: telnyx_verify_id,
      timeout_secs: 300
    }
    # submits verification
    Telnyx::Verification.create(verification)
    puts 'Sending Verification Code to: ' + phone_number
    phone_number
  end

  rescue Exception => e
    puts 'Error sending verification'
    puts e
    exit
end

# handles verification
def code_verify(phone_number)
  # loop for attempts before break
  attempts = 0
  max_attempts = 5
  while attempts < max_attempts do
    puts 'Verification code?: '
    code_input = gets.chomp
    # iterator, ++
    attempts +=1
    begin
      # verify request object
      verify_request = {
        phone_number: phone_number,
        code: code_input
      }
      # submits request
      telnyx_response = Telnyx::Verification.submit_code(verify_request)
      if telnyx_response.response_code == 'accepted'
        puts 'Code accepted!'
        break
      else
        puts 'Code rejected, try again!'
        if attempts >= max_attempts
          puts 'Verification max attempts reached, goodbye...'
        end
      end
    rescue Exception => ex
      puts 'Error verifying code'
      puts ex
      exit
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  # env variables / sets API Key
  TELNYX_API_KEY = ENV.fetch('TELNYX_API_KEY')
  Telnyx.api_key = TELNYX_API_KEY
  telnyx_verify_id = ENV.fetch('TELNYX_VERIFY_PROFILE_ID')


  send_verify = send_verify(telnyx_verify_id)
  code_verify(send_verify)
end
