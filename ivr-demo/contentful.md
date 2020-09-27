⏱ **30 minutes build time**

## Introduction

The [Call Control framework](/docs/api/v2/call-control) is a set of APIs that allow complete control of a call flow from the moment a call begins to the moment it is completed. In between, you will receive a number of [webhooks](/docs/v2/call-control/receiving-webhooks) for each step of the call, allowing you to act on these events and send commands using the Telnyx Library.


The [Telnyx Ruby Library](https://github.com/team-telnyx/telnyx-ruby) is a convenient wrapper around the Telnyx REST API. It allows you to access and control call flows using an intuitive object-oriented library. This tutorial will walk you through creating a simple Sinatra server that allows you to create an IVR demo application.

## Setup

Before beginning, please setup ensure that you have the Telnyx, Dotenv, and Sinatra gems installed.

```shell
gem install telnyx sinatra dotenv
```

Alternatively, create a Gemfile for your project

```ruby
source 'https://rubygems.org'

gem 'sinatra'
gem 'telnyx'
gem 'dotenv'
```

### Setting environment variables

The following environmental variables need to be set

| Variable            | Description                                                                                                                                              |
|:--------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `TELNYX_API_KEY`    | Your [Telnyx API Key](https://portal.telnyx.com/#/app/api-keys?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)              |
| `TELNYX_PUBLIC_KEY` | Your [Telnyx Public Key](https://portal.telnyx.com/#/app/account/public-key?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) |
| `TELNYX_APP_PORT`   | **Defaults to `8000`** The port the app will be served                                                                                                   |

### .env file

This app uses the excellent [dotenv](https://github.com/bkeepers/dotenv) package to manage environment variables.

Make a copy of the file below, add your credentials, and save as `.env` in the root directory.

```
TELNYX_API_KEY=
TELNYX_PUBLIC_KEY=
TENYX_APP_PORT=8000
```

### Portal Setup

You’ll need set up a Mission Control Portal account, buy a number and connect that number to a [Call Control Application](https://portal.telnyx.com/#/app/call-control/applications). You can learn how to do that in the quickstart guide [here](/docs/v2/call-control/quickstart).

The [Call Control Application](https://portal.telnyx.com/#/app/call-control/applications) needs to be setup to work with the conference control api:

* make sure the *Webhook API Version* is **API v2**

* Fill in the *Webhook URL* with the address the server will be running on. Alternatively, you can use a service like [Ngrok](https://ngrok.com/) to temporarily forward a local port to the internet to a random address and use that. We'll talk about this in more detail later.

Finally, you need to create an [API Key](https://portal.telnyx.com/#/app/auth/v2) - make sure you save the key somewhere safe.

Now create a file such as `ivr_demo_server.rb`, then write the following to setup the telnyx library.

```ruby
# frozen_string_literal: true

require 'sinatra'
require 'telnyx'
require 'dotenv/load'

# Setup telnyx api key.
Telnyx.api_key = ENV.fetch('TELNYX_API_KEY')

```

## Receiving Webhooks & Answering a call

Now that you have setup your auth token and call_control_id, you can begin to use the API Library to answer a call and receive input from [DTMF](https://support.telnyx.com/en/articles/1130710-what-is-dtmf). First, you will need to setup a Sinatra endpoint to receive webhooks for call and DTMF events. There are a number of webhooks that you should anticipate receiving during the lifecycle of each call. This will allow you to take action in response to any number of events triggered during a call. In this example, you will use the `call.initiated` and `call.answered` events to answer the incoming call and then present IVR options to the user.  You'll use the `call.gather.ended` event to parse the digits pressed during the IVR.

```ruby
# ...
set :port, ENV.fetch('TELNYX_APP_PORT')
post '/webhook' do
  # Parse the request body.
  request.body.rewind
  body = request.body.read # Save the body for verification later
  data = JSON.parse(body)['data']

  # Handle events
  if data['record_type'] == 'event'
    call = Telnyx::Call.new id: data['payload']['call_control_id'],
                            call_leg_id: data['payload']['call_leg_id']
    case data['event_type']
    when 'call.initiated'
      # Answer the call, this will cause the api to send another webhook event
      # of the type call.answered, which we will handle below.
      call.answer
      puts('Answered Call')

    when 'call.answered'
      # Start to gather information, using the prompt "Press a digit"
      call.gather_using_speak(voice: 'female',
                              language: 'en-US',
                              payload: 'Press some digits! The only valid options are 1 2 3',
                              valid_digits: '123',
                              invalid_payload: 'Invalid Entry Please try again')
      puts('Gather sent')

    when 'call.gather.ended'
      # Only care about the digits captured during the gather request
      if data['payload']['status'] != 'call_hangup'
        # Ensure that the reason for ending was NOT a hangup (can't speak on an ended call)
        call.speak(voice: 'female',
                   language: 'en-US',
                   payload: "You pressed: #{data['payload']['digits']}, You can now hangup")
        puts('DTMF spoke')
      end
    end
  end
end
```

Pat youself on the back - that's a lot of code to go through! Now let's break it down even further and explain what it does. First, create an array for keeping track of the ongoing calls so that we can differentiate. Then, tell Sinatra to listen on the port defined in the `.env` file and create an endpoint at `/webhook`, which can be anything you choose as the API doesn't care; here we just call it webhook.

```ruby
set :port, ENV.fetch('TELNYX_APP_PORT')

post "/webhook" do
# ...
end
```

Next, parse the data from the API server, check to see if it is a webhook event, and act on it if it is. Then, you will define what actions to take on different types of events.  The webhook endpoint is only tuned to accept call events. You can create a `call` object from the `call_control_id` nested in the `webhook.data.payload` JSON. This will allow you to send commands to the active call.

```ruby
post '/webhook' do
  # Parse the request body.
  request.body.rewind
  body = request.body.read # Save the body for verification later
  data = JSON.parse(body)['data']
  # Handle events
  if data['record_type'] == 'event'
    call = Telnyx::Call.new id: data['payload']['call_control_id'],
                            call_leg_id: data['payload']['call_leg_id']
    case data['event_type']
    end
  end
end
```

Here is where you will respond to a new call being initiated, which can be from either an inbound or outbound call. Create a new `Telnyx::Call` object and store it in the active call list, then call `call.answer` to answer it if it's an inbound call.

```ruby
when 'call.initiated'
  # Answer the call, this will cause the api to send another webhook event
  # of the type call.answered, which we will handle below.
  call.answer
  puts('Answered Call')
```

On the `call.answered` event, we can call the `gather_using_speak` command to speak audio and gather DTMF information from the user input.

Take note that the `valid_digits` restricts the input to the caller to only the digits specified. The `invalid_payload` will be played back to the caller before the `payload` is repeated back if any invalid digits are pressed when the gather completes.

```ruby
when 'call.answered'
  # Start to gather information, using the prompt "Press a digit"
  call.gather_using_speak(voice: 'female',
                          language: 'en-US',
                          payload: 'Press some digits! The only valid options are 1 2 3',
                          valid_digits: '123',
                          invalid_payload: 'Invalid Entry Please try again')
  puts('Gather sent')
```

Now, once we have our setup complete, when the gather is complete due to one of the statuses: ( `valid`, `invalid`, `call_hangup`, `cancelled`, `cancelled_amd`), the `call.gather.ended` event is sent to the `webhook` endpoint. From there, we can extract the `digits` field from the `payload` and play it back to the user using `speak`.

Take note that the `call_hangup` status indicates the caller hungup before the gather could complete. For that case, we're done as `speak` does not work on an ended call.

```ruby
when 'call.gather.ended'
  # Only care about the digits captured during the gather request
  if data['payload']['status'] != 'call_hangup'
    # Ensure that the reason for ending was NOT a hangup (can't speak on an ended call)
    call.speak(voice: 'female',
               language: 'en-US',
               payload: "You pressed: #{data['payload']['digits']}, You can now hangup")
    puts('DTMF spoke')
  end
end
```


## Authentication

Now you have a working conference application! How secure is it though? Could a 3rd party simply craft fake webhooks to manipulate the call flow logic of your application? Telnyx has you covered with a powerful signature verification system!

Make the following changes:

```ruby
# ...
post '/webhook' do
  # Parse the request body.
  request.body.rewind
  body = request.body.read # Save the body for verification later
  data = JSON.parse(body)['data']
  begin
    Telnyx::Webhook::Signature.verify(body,
                                      request.env['HTTP_TELNYX_SIGNATURE_ED25519'],
                                      request.env['HTTP_TELNYX_TIMESTAMP'])
  rescue Exception => e
    puts e
    halt 400, 'Webhook signature not valid'
  end
# ...
```

Your public key is read from the Environment variables defined in your `.env` file. Look up your public key from the Telnyx Portal [here](https://portal.telnyx.com/#/app/account/public-key). `Telnyx::Webhook::Signature.verify` will do the work of verifying the authenticity of the message, and raise `SignatureVerificationError` if the signature does not match the payload.

## Final `ivr_demo_server.rb`

All together, your `ivr_demo_server.rb` file should resemble something like:

```ruby
# frozen_string_literal: true

require 'sinatra'
require 'telnyx'
require 'dotenv/load'

# Setup telnyx api key.
Telnyx.api_key = ENV.fetch('TELNYX_API_KEY')

set :port, ENV.fetch('TELNYX_APP_PORT')
post '/webhook' do
  # Parse the request body.
  request.body.rewind
  body = request.body.read # Save the body for verification later
  data = JSON.parse(body)['data']
  begin
    Telnyx::Webhook::Signature.verify(body,
                                      request.env['HTTP_TELNYX_SIGNATURE_ED25519'],
                                      request.env['HTTP_TELNYX_TIMESTAMP'])
  rescue Exception => e
    puts e
    halt 400, 'Webhook signature not valid'
  end
  # Handle events
  if data['record_type'] == 'event'
    call = Telnyx::Call.new id: data['payload']['call_control_id'],
                            call_leg_id: data['payload']['call_leg_id']
    case data['event_type']
    when 'call.initiated'
      # Answer the call, this will cause the api to send another webhook event
      # of the type call.answered, which we will handle below.
      call.answer
      puts('Answered Call')

    when 'call.answered'
      # Start to gather information, using the prompt "Press a digit"
      call.gather_using_speak(voice: 'female',
                              language: 'en-US',
                              payload: 'Press some digits! The only valid options are 1 2 3',
                              valid_digits: '123',
                              invalid_payload: 'Invalid Entry Please try again')
      puts('Gather sent')

    when 'call.gather.ended'
      # Only care about the digits captured during the gather request
      if data['payload']['status'] != 'call_hangup'
        # Ensure that the reason for ending was NOT a hangup (can't speak on an ended call)
        call.speak(voice: 'female',
                   language: 'en-US',
                   payload: "You pressed: #{data['payload']['digits']}, You can now hangup")
        puts('DTMF spoke')
      end
    end
  end
end
```

## Usage

If you used a Gemfile, start the conference server with `bundle exec ruby ivr_demo_server.rb`, if you are using globally installed gems use `ruby ivr_demo_server.rb`.

When you are able to run the server locally, the final step involves making your application accessible from the internet. So far, we've set up a local web server. This is typically not accessible from the public internet, making testing inbound requests to web applications difficult.

The best workaround is a tunneling service. They come with client software that runs on your computer and opens an outgoing permanent connection to a publicly available server in a data center. Then, they assign a public URL (typically on a random or custom subdomain) on that server to your account. The public server acts as a proxy that accepts incoming connections to your URL, forwards (tunnels) them through the already established connection and sends them to the local web server as if they originated from the same machine. The most popular tunneling tool is `ngrok`. Check out the [ngrok setup](/docs/v2/development/ngrok) walkthrough to set it up on your computer and start receiving webhooks from inbound messages to your newly created application.

Once you've set up `ngrok` or another tunneling service you can add the public proxy URL to your Connection in the MIssion Control Portal. To do this, click  the edit symbol [✎] next to your Connection. In the "Webhook URL" field, paste the forwarding address from ngrok into the Webhook URL field. Add `/webhook` to the end of the URL to direct the request to the webhook endpoint in your Sinatra server.

### Callback URLs For Telnyx Applications

| Callback Type          | URL                   |
|:-----------------------|:----------------------|
| Inbound Calls Callback | `{ngrok-url}/webhook` |

For now you'll leave “Failover URL” blank, but if you'd like to have Telnyx resend the webhook in the case where sending to the Webhook URL fails, you can specify an alternate address in this field.


## Complete Running Call Control IVR Application

You have now created a simple IVR application! Using other Call Commands, you can perform actions based on user input collected during a gather. For more information on what call commands you can use, check out the [Call Command Documentation](https://developers.telnyx.com/docs/api/v2/call-control/Call-Commands "Call Command Documentation")