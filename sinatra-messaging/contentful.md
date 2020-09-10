# Title

⏱ **30 minutes build time || [Github Repo]()**

## Introduction

Telnyx's messaging API supports both MMS and SMS messsages. Inbound multimedia messaging (MMS) messages include an attachment link in the webhook. The link and corresponding media should be treated as ephemeral and you should save any important media to a media storage (such as AWS S3) of your own.


## What you can do

At the end of this tutorial you'll have an application that:

* Receives an inbound message (SMS or MMS)
* Iterates over any media attachments and downloads the remote attachment locally
* Uploads the same attachment to AWS S3
* Sends the attachments back to the same phone number that originally sent the message


## Pre-reqs & technologies

* Completed or familiar with the [Receiving SMS & MMS Quickstart](docs/v2/messaging/quickstarts/receiving-sms-and-mms)
* A working [Messaging Profile](https://portal.telnyx.com/#/app/messaging) with a phone number enabled for SMS & MMS.
* [Ruby & Gem](docs/v2/development/dev-env-setup?lang=ruby&utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) installed
* [Familiarity with Sinatra](http://sinatrarb.com/)
* Ability to receive webhooks (with something like [ngrok](docs/v2/development/ngrok))
* AWS Account setup with proper profiles and groups with IAM for S3. See the [Quickstart](https://docs.aws.amazon.com/sdk-for-javascript/index.html) for more information.
* Previously created S3 bucket with public permissions available.

## Setup

### Telnyx Portal configuration

Be sure to have a [Messaging Profile](https://portal.telnyx.com/#/app/messaging) with a phone number enabled for SMS & MMS and webhook URL pointing to your service (using ngrok or similar)

### Install packages via Gem/bundler

```shell
gem install telnyx
gem install sinatra
gem install dotenv
gem install ostruct
gem install json
gem install aws-sdk
gem install down
```

This will create `Gemfile` file with the packages needed to run the application.

### Setting environment variables

The following environmental variables need to be set

| Variable               | Description                                                                                                                                              |
|:-----------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `TELNYX_API_KEY`       | Your [Telnyx API Key](https://portal.telnyx.com/#/app/api-keys?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)              |
| `TELNYX_PUBLIC_KEY`    | Your [Telnyx Public Key](https://portal.telnyx.com/#/app/account/public-key?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) |
| `TELNYX_APP_PORT`      | **Defaults to `8000`** The port the app will be served                                                                                                   |
| `AWS_PROFILE`          | Your AWS profile as set in `~/.aws`                                                                                                                      |
| `AWS_REGION`           | The region of your S3 bucket                                                                                                                             |
| `TELNYX_MMS_S3_BUCKET` | The name of the bucket to upload the media attachments                                                                                                   |

### .env file

This app uses the excellent [dotenv](https://github.com/bkeepers/dotenv) package to manage environment variables.

Make a copy of the file below, add your credentials, and save as `.env` in the root directory.

```
TELNYX_API_KEY=
TELNYX_PUBLIC_KEY=
TENYX_APP_PORT=8000
AWS_PROFILE=
AWS_REGION=
TELNYX_MMS_S3_BUCKET=
```


## Code-along

We'll use a singe `app.rb` file to build the MMS application.

```
touch app.rb
```

### Setup Sinatra Server

```ruby
require 'sinatra'
require 'telnyx'
require 'dotenv/load'
require 'json'
require 'ostruct'
require 'aws-sdk-s3'
require 'down'

if __FILE__ == $0
  TELNYX_API_KEY=ENV.fetch("TELNYX_API_KEY")
  TELNYX_APP_PORT=ENV.fetch("TELNYX_APP_PORT")
  AWS_REGION = ENV.fetch("AWS_REGION")
  TELNYX_MMS_S3_BUCKET = ENV.fetch("TELNYX_MMS_S3_BUCKET")
  Telnyx.api_key = TELNYX_API_KEY
  set :port, TELNYX_APP_PORT
end

get '/' do
  "Hello World"
end

```

## Receiving Webhooks

Now that you have setup your auth token, phone number, and connection, you can begin to use the API Library to send/receive SMS & MMS messages. First, you will need to setup an endpoint to receive webhooks for inbound messages & outbound message Delivery Receipts (DLR).

### Basic Routing & Functions

The basic overview of the application is as follows:

1. Verify webhook & create TelnyxEvent
2. Extract information from the webhook
3. Iterate over any media and download/re-upload to S3 for each attachment
4. Send the message back to the phone number from which it came
5. Acknowledge the status update (DLR) of the outbound message

### Media Download & Upload Functions

Before diving into the inbound message handler, first we'll create a few functions to manage our attachments.

* `download_file` saves the content from a URL to disk
* `upload_file` uploads the file passed to AWS S3 (and makes object public)

```ruby
def upload_file(file_path)
  s3 = Aws::S3::Resource.new(region: AWS_REGION)
  name = File.basename(file_path)
  obj = s3.bucket(TELNYX_MMS_S3_BUCKET).object(name)
  obj.upload_file(file_path, acl: 'public-read')
  obj.public_url
end

def download_file(uri)
  temp_file = Down.download(uri)
  path = "./#{temp_file.original_filename}"
  FileUtils.mv(temp_file.path, path)
  path
end
```

### Inbound Message Handling

Now that we have the functions to manage the media, we can start receiving inbound MMS's

The flow of our function is (at a high level):
1. Extract relevant information from the webhook
2. Build the `webhook_url` to direct the DLR to a new endpoint
3. Iterate over any attachments/media and call our `downloadUpload` function
4. Send the outbound message back to the original sender with the media attachments


```ruby
def deserialize_json(json)
  object = JSON.parse(json, object_class: OpenStruct)
  object
end

post '/messaging/inbound' do
  webhook = deserialize_json(request.body.read)
  dlr_uri = URI::HTTP.build(host: request.host, path: '/messaging/outbound')
  to_number = webhook.data.payload.to[0].phone_number
  from_number = webhook.data.payload.from.phone_number
  media = webhook.data.payload.media
  file_paths = []
  media_urls = []
  if media.any?
    media.each do |item|
      file_path = download_file(item.url)
      file_paths.push(file_path)
      media_url = upload_file(file_path)
      media_urls.push(media_url)
    end
  end

  begin
    telnyx_response = Telnyx::Message.create(
        from: to_number,
        to: from_number,
        text: "Hello, world!",
        media_urls: media_urls,
        use_profile_webhooks: false,
        webhook_url: dlr_uri.to_s
    )
    puts "Sent message with id: #{telnyx_response.id}"
  rescue Exception => ex
    puts ex
  end
end
```

### Outbound Message Handling

As we defined our `webhook_url` path to be `/messaging/outbound` we'll need to create a function that accepts a POST request to that path within messaging.js.

```ruby
post '/messaging/outbound' do
  webhook = deserialize_json(request.body.read)
  puts "Received message DLR with ID: #{webhook.data.payload.id}"
end
```

### Final app.rb

All together the app.rb should look something like:

```ruby
require 'sinatra'
require 'telnyx'
require 'dotenv/load'
require 'json'
require 'ostruct'
require 'aws-sdk-s3'
require 'down'

if __FILE__ == $0
  TELNYX_API_KEY=ENV.fetch("TELNYX_API_KEY")
  TELNYX_APP_PORT=ENV.fetch("TELNYX_APP_PORT")
  AWS_REGION = ENV.fetch("AWS_REGION")
  TELNYX_MMS_S3_BUCKET = ENV.fetch("TELNYX_MMS_S3_BUCKET")
  Telnyx.api_key = TELNYX_API_KEY
  set :port, TELNYX_APP_PORT
end

get '/' do
  "Hello World"
end

def deserialize_json(json)
  object = JSON.parse(json, object_class: OpenStruct)
  object
end

def upload_file(file_path)
  s3 = Aws::S3::Resource.new(region: AWS_REGION)
  name = File.basename(file_path)
  obj = s3.bucket(TELNYX_MMS_S3_BUCKET).object(name)
  obj.upload_file(file_path, acl: 'public-read')
  obj.public_url
end

def download_file(uri)
  temp_file = Down.download(uri)
  path = "./#{temp_file.original_filename}"
  FileUtils.mv(temp_file.path, path)
  path
end


post '/messaging/inbound' do
  webhook = deserialize_json(request.body.read)
  dlr_uri = URI::HTTP.build(host: request.host, path: '/messaging/outbound')
  to_number = webhook.data.payload.to[0].phone_number
  from_number = webhook.data.payload.from.phone_number
  media = webhook.data.payload.media
  file_paths = []
  media_urls = []
  if media.any?
    media.each do |item|
      file_path = download_file(item.url)
      file_paths.push(file_path)
      media_url = upload_file(file_path)
      media_urls.push(media_url)
    end
  end

  begin
    telnyx_response = Telnyx::Message.create(
        from: to_number,
        to: from_number,
        text: "Hello, world!",
        media_urls: media_urls,
        use_profile_webhooks: false,
        webhook_url: dlr_uri.to_s
    )
    puts "Sent message with id: #{telnyx_response.id}"
  rescue Exception => ex
    puts ex
  end
end

post '/messaging/outbound' do
  webhook = deserialize_json(request.body.read)
  puts "Received message DLR with ID: #{webhook.data.payload.id}"
end
```

## Usage

Start the server `ruby app.rb`

When you are able to run the server locally, the final step involves making your application accessible from the internet. So far, we've set up a local web server. This is typically not accessible from the public internet, making testing inbound requests to web applications difficult.

The best workaround is a tunneling service. They come with client software that runs on your computer and opens an outgoing permanent connection to a publicly available server in a data center. Then, they assign a public URL (typically on a random or custom subdomain) on that server to your account. The public server acts as a proxy that accepts incoming connections to your URL, forwards (tunnels) them through the already established connection and sends them to the local web server as if they originated from the same machine. The most popular tunneling tool is `ngrok`. Check out the [ngrok setup](/docs/v2/development/ngrok) walkthrough to set it up on your computer and start receiving webhooks from inbound messages to your newly created application.

Once you've set up `ngrok` or another tunneling service you can add the public proxy URL to your Inbound Settings  in the Mission Control Portal. To do this, click  the edit symbol [✎] next to your Messaging Profile. In the "Inbound Settings" > "Webhook URL" field, paste the forwarding address from ngrok into the Webhook URL field. Add `messaging/inbound` to the end of the URL to direct the request to the webhook endpoint in your  server.

### Callback URLs For Telnyx Applications

| Callback Type                    | URL                              |
|:---------------------------------|:---------------------------------|
| Inbound Message Callback         | `{ngrok-url}/messaging/inbound`  |
| Outbound Message Status Callback | `{ngrok-url}/messaging/outbound` |

For now you'll leave “Failover URL” blank, but if you'd like to have Telnyx resend the webhook in the case where sending to the Webhook URL fails, you can specify an alternate address in this field.

Once everything is setup, you should now be able to:
* Text your phone number and receive a response!
* Send a picture to your phone number and get that same picture right back!

