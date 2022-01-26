<div align="center">

# Telnyx-Ruby Phone Number List and parse

![Telnyx](../logo-dark.png)

Sample application demonstrating Telnyx-Ruby listing phone numbers

</div>

## Documentation & Tutorial

The full documentation and tutorial is available on developers.telnyx.com

## Pre-Reqs

You will need to set up:

* [Telnyx Account](https://telnyx.com/sign-up?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)
* [Telnyx Phone Number](https://portal.telnyx.com/#/app/numbers/my-numbers?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) enabled with:
  * [Telnyx Call Control Application](https://portal.telnyx.com/#/app/call-control/applications?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)
  * [Telnyx Outbound Voice Profile](https://portal.telnyx.com/#/app/outbound-profiles?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)
* [Ruby & Gem](https://developers.telnyx.com/docs/v2/development/dev-env-setup?lang=ruby&utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link) installed

## What you can do

* List the phone numbers on your account
* Get a list of those numbers with messaging settings
* Get a list of those numbers with voice-settings

## Usage

The following environmental variables need to be set

| Variable               | Description                                                                                                                                              |
|:-----------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `TELNYX_API_KEY`       | Your [Telnyx API Key](https://portal.telnyx.com/#/app/api-keys?utm_source=referral&utm_medium=github_referral&utm_campaign=cross-site-link)              |


### .env file

This app uses the excellent [dotenv](https://github.com/bkeepers/dotenv) package to manage environment variables.

Make a copy of [`.env.sample`](./.env.sample) and save as `.env` and update the variables to match your creds.

```
TELNYX_API_KEY=
```


### Install

Run the following commands to get started

```
$ git clone https://github.com/team-telnyx/demo-ruby-telnyx.git
```
### Run

Open your IDE and run the application

## Next Steps