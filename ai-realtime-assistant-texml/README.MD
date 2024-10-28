# Speech Assistant with Telnyx Voice and the OpenAI Realtime API (Ruby)

This application demonstrates how to use **Ruby**, [Telnyx Voice](https://developers.telnyx.com/docs/voice/programmable-voice/get-started) with [TeXML](https://developers.telnyx.com/docs/voice/programmable-voice/texml-setup), and [OpenAI's Realtime API](https://platform.openai.com/docs/) to make a phone call to speak with an AI Assistant.

The application opens WebSocket connections with the OpenAI Realtime API and Telnyx, and sends voice audio between them to enable a two-way conversation.

This application uses the following Telnyx products in conjunction with OpenAI's Realtime API:

- **Voice** (TeXML, WebRTC)
- **Phone Numbers**

## Prerequisites

To use the app, you will need:

- **A Telnyx account.** You can [sign up for free](https://telnyx.com/sign-up).
- **Ruby 2.6+** You can download it from [here](https://www.ruby-lang.org/en/downloads/).
- **Bundler** (optional but recommended). Install with `gem install bundler`.
- **A Telnyx number with _Voice_ capabilities.** You can find [a walkthrough to purchase a phone number here](https://support.telnyx.com/en/articles/4380325-search-and-buy-numbers).
- **An OpenAI account and an OpenAI API Key.** You can [sign up here](https://platform.openai.com/).
- **OpenAI Realtime API access.**
- **Ngrok** or another tunneling service.

## Local Setup Overview

This project can be summarized by the following steps:

1. **Set up port forwarding** using a tunneling service like **Ngrok** to expose your local server to the internet.
2. **Configure your Telnyx account** with a phone number that has Voice capabilities.
3. **Fill out the `.env` file** with your API keys and configuration.
4. **Install dependencies** required by the Ruby application.
5. **Run the project** and start the server.

### 1. Open an Ngrok Tunnel

To allow external services (like Telnyx) to communicate with your local server, you need to expose it to the internet. We recommend using **Ngrok** for this purpose.

#### Install Ngrok

If you haven't installed Ngrok yet, you can download it from the [official website](https://ngrok.com/download).

#### Run Ngrok

Open a terminal and run:

```bash
ngrok http 8000
```

You should see output similar to:

```
ngrok by @inconshreveable

Session Status                online
Account                       Your Name (Plan: Free)
Version                       2.x.x
Region                        United States (us)
Web Interface                 http://127.0.0.1:4040
Forwarding                    http://abcd1234.ngrok.io -> http://localhost:8000
Forwarding                    https://abcd1234.ngrok.io -> http://localhost:8000

Connections                   ttl     opn     rt1     rt5     p50     p90
                              0       0       0.00    0.00    0.00    0.00
```

Take note of the `Forwarding` URLs. You'll need the `https` URL (e.g., `https://abcd1234.ngrok.io`) for configuring Telnyx.

### 2. Configure Telnyx

#### Create a TeXML Application

1. Log in to your [Telnyx Mission Control Portal](https://portal.telnyx.com/).
2. Navigate to **"TeXML Applications"** under **"Call Control"**.
3. Click **"Add TeXML Application"**.
4. In the **"App Info"** section:
   - **Name:** Give your application a name (e.g., "Ruby AI Assistant").
   - **"Send a webhook to the URL:"** Paste your Ngrok forwarding URL with `/inbound` appended (e.g., `https://abcd1234.ngrok.io/inbound`).
   - **"HTTP Method"** should be **POST**.
5. Click **"Save"**.

#### Assign the TeXML Application to Your Phone Number

1. Go to **"Numbers"** in the Mission Control Portal.
2. Click on the phone number you want to use.
3. In the **"Voice Settings"** section:
   - **"Connection"**: Select the TeXML application you just created.
4. Click **"Save"**.

### 3. Fill Out the `.env` File

1. In your project directory, copy the `.env.sample` file to `.env`:

   ```bash
   cp .env.sample .env
   ```

2. Open the `.env` file in a text editor and fill in the following variables:

   ```env
   OPENAI_API_KEY=your_openai_api_key_here
   PORT=8000
   ```

   - Replace `your_openai_api_key_here` with your actual OpenAI API key.
   - Ensure `PORT` matches the port you're running your local server on (default is `8000`).

### 4. Install Dependencies

We recommend using **Bundler** to manage dependencies.

#### Using Bundler

1. Install Bundler if you haven't already:

   ```bash
   gem install bundler
   ```

2. Create a `Gemfile` in your project directory with the following content:

   ```ruby
   source 'https://rubygems.org'

   gem 'sinatra'
   gem 'dotenv'
   gem 'faye-websocket'
   gem 'thin'
   gem 'json'
   ```

3. Install the gems:

   ```bash
   bundle install
   ```

#### Without Bundler

If you prefer not to use Bundler, install the required gems manually:

```bash
gem install sinatra dotenv faye-websocket thin json
```

### 5. Run the Project

Run the server with the following command:

```bash
ruby app.rb
```

You should see output indicating that the server is running on port `8000`.

## Test the App

Now that your server is running and exposed to the internet via Ngrok, and Telnyx is configured to send calls to your application, you can test the app:

1. **Call Your Telnyx Phone Number:**
   - Use any phone to call the Telnyx number you've configured.
2. **Interact with the AI Assistant:**
   - You should hear a friendly AI assistant greeting you.
   - Speak to the assistant and it should respond accordingly.

## Additional Information

### Project Structure

- **`app.rb`**: The main Ruby application file containing all the server and WebSocket logic.
- **`texml.xml`**: The TeXML file that defines the call flow.
- **`.env`**: Environment variables file containing your API keys and configuration.
- **`Gemfile`**: Contains the list of gems required by the application (if using Bundler).

### Environment Variables

Make sure to keep your `.env` file secure and **never** commit it to version control. It contains sensitive information like your API keys.

### CORS Configuration

Sinatra does not require explicit middleware for CORS in this context. If you need to enable CORS, you can add the following before filter in `app.rb`:

```ruby
before do
  response.headers['Access-Control-Allow-Origin'] = '*'
end
```

### Logging

You can enhance logging by integrating with a logging library or using Sinatra's built-in logging facilities. For example, you can enable logging in Sinatra by setting:

```ruby
configure do
  enable :logging
end
```

### Handling SSL Certificates

When working with WebSockets and external APIs, you might encounter SSL certificate errors. Ensure your Ruby installation includes SSL support, and you have the necessary certificates installed.

## Troubleshooting

- **Ngrok URL Not Working:**
  - Ensure Ngrok is running and that you're using the correct forwarding URL.
  - Remember that Ngrok URLs change every time you start it unless you have a paid plan with custom domains.
- **Telnyx Not Sending Requests:**
  - Double-check that your TeXML application is configured with the correct Webhook URL and that it's assigned to your phone number.
- **Dependencies Issues:**
  - Ensure all required gems are installed.
  - If you encounter version conflicts, try updating the gems or using Bundler to manage versions.
- **OpenAI API Errors:**
  - Verify that your OpenAI API key is correct and that you have access to the Realtime API.
  - Check for any rate limiting or usage caps on your OpenAI account.

## Resources

- **Telnyx Documentation:**
  - [Voice API](https://developers.telnyx.com/docs/voice)
  - [TeXML](https://developers.telnyx.com/docs/voice/programmable-voice/texml-setup)
- **OpenAI Documentation:**
  - [Realtime API](https://platform.openai.com/docs/)
- **Ruby Documentation:**
  - [Ruby Language](https://www.ruby-lang.org/en/documentation/)
  - [Sinatra Framework](https://sinatrarb.com/documentation.html)
  - [Faye WebSocket](https://github.com/faye/faye-websocket-ruby)
- **Ngrok Documentation:**
  - [Getting Started](https://ngrok.com/docs)

## Contributing

Feel free to contribute to this project by submitting issues or pull requests. Please make sure to follow the project's code style and include appropriate tests.

## License

This project is licensed under the MIT License.
