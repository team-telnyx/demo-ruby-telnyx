<div align="center">

# Telnyx-Ruby WebRTC Login Token

![Telnyx](../logo-dark.png)

Sample application minting WebRTC login tokens locally with Telnyx-Ruby

</div>

## Documentation & Tutorial

The full documentation and tutorial is available on [developers.telnyx.com](https://developers.telnyx.com/docs/v2/development/dev-env-setup)

## Pre-Reqs

You will need to set up:

* [Telnyx Account](https://telnyx.com/sign-up?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)
* [Telnyx Credential Connection](https://portal.telnyx.com/#/app/connections) for WebRTC
* [Ruby & Gem](https://developers.telnyx.com/docs/v2/development/dev-env-setup?lang=ruby&utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) installed

## What you can do

* Create a telephony credential (or reuse one) on a credential connection
* Mint a WebRTC login token for it on your own server with `TelephonyCredential#to_jwt`, without a request to Telnyx per login
* Check the token by logging in to the WebRTC gateway, the way the WebRTC SDKs do

`to_jwt` needs Telnyx-Ruby 3.1.0 or later (`gem "telnyx", "~> 3.1"`).

## Usage

The following environmental variables need to be set

| Variable                | Description                                                                                                                                 |
|:------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------|
| `TELNYX_API_KEY`        | Your [Telnyx API Key](https://portal.telnyx.com/#/app/api-keys?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) |
| `TELNYX_CONNECTION_ID`  | The id of your [credential connection](https://portal.telnyx.com/#/app/connections)                                                         |
| `TELNYX_CREDENTIAL_ID`  | Optional: an existing telephony credential to reuse instead of creating one on every run                                                     |
| `TELNYX_API_BASE`       | Optional: the API host the SDK talks to, `https://api.telnyx.com` by default                                                                 |
| `TELNYX_RTC_URL`        | Optional: the WebRTC gateway the login check connects to, `wss://rtc.telnyx.com` by default                                                   |

### .env file

This app uses the [dotenv](https://github.com/bkeepers/dotenv) gem to manage environment variables.

Make a copy of [`.env.sample`](./.env.sample) and save as `.env` and update the variables to match your creds.

```
TELNYX_API_KEY=KEY0...R1LI
TELNYX_CONNECTION_ID=1234567890123456789
```

### Install

Run the following commands to get started

```
$ git clone https://github.com/team-telnyx/demo-ruby-telnyx.git
$ cd demo-ruby-telnyx/webrtc-login-token
$ bundle install
```

### Run

Start the app with `bundle exec ruby app.rb`

When the application is started:
* A telephony credential is created on your connection (or the one in `TELNYX_CREDENTIAL_ID` is retrieved)
* A login token valid for one hour is minted locally and printed. Hand a token like this to the WebRTC SDK as its `login_token`
* The app logs in to the WebRTC gateway with it and prints the answer. A credential created a moment ago takes a few seconds to be known by the gateways, so the login is retried a few times

The token is computed from the credential's `token_material`, which the API returns when the credential is created with `include: "token_material"` (and on `GET /v2/telephony_credentials/{id}/token_material`). Store it with the credential's `id`, `user_id`, `sip_username` and `expires_at`, server side, and you can mint tokens for as long as the credential lives, with no further requests.
