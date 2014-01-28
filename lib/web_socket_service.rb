require './config/application.rb'
require 'em-websocket'
require 'json'
require 'trading_core/trading_api/base'

class WebSocketService
  def initialize(socket, client_data_broker)
    @socket = socket
    @client_data_broker = client_data_broker

    @socket.onopen do
      puts 'New connection established'
    end
  
    @socket.onmessage do |message|
      handle_message(message)
    end
    
    @socket.onclose do
      handle_close
    end
    
    @socket.onerror do |event|
      handle_error(event)
    end
  end
  
  def update(message)
    # Forward the message to the client.
    @socket.send(message.to_json)
  end

  private
  
  def handle_message(message)
    message = JSON.parse(message)
    
    message_type = message['type']
    message_data = message['data']

    case message_type
      when TradingApi.types[:login]
        # Look up the account by token.
        @account = TradingCore::Account.find_by_token(message_data['token'])
        if !@account
          response_data = {
            :type => TradingApi.types[:login],
            :data => { :logged_in => false }
          }
          @socket.send(response_data.to_json)
          @socket.stop
        end
        
        # Get a reference to the API client.
        @api = @account.api
        @streamer = @account.streamer
        
        # Now that we're logged in, make this class observe API changes.
        @api.add_observer(self)
        
        # Send success response
        response_data = {
          :type => TradingApi.types[:login],
          :data => { :logged_in => true }
        }
        @socket.send(response_data.to_json)
      
      when TradingApi.types[:quote]
        quote = @api.quotes(message_data['symbol'])[0]
        response_data = {
          :type => TradingApi.types[:quote],
          :data => quote
        }
        @socket.send(response_data.to_json)
        
      when TradingApi.types[:stream_quotes]
        message_data['symbols'].each do |symbol|
          @client_data_broker.add_client(@socket, symbol)
        end
        
      when TradingApi.types[:buy]
        @api.buy(message_data['symbol'], message_data['investment'].to_f, message_data['price'].to_f)
        
      when TradingApi.types[:sell]
        price = nil
        price = message_data['price'].to_f if message_data['price']
        
        begin
          @api.sell(message_data['symbol'], message_data['shares'].to_f, price)
        rescue TradingApi::TradingError => error
          @socket.send({ :error => error.message })
        end
        
      when TradingApi.types[:positions]
        @api.positions

        # TODO Keep positions data up to date. Perhaps use some sort or interval here.
        # ...

      when TradingApi.types[:chart_data]
        # Retrieve all available stock data for the given security.
        security = TradingCore::Security.where(:symbol => message_data['symbol']).first
        quotes = security.historical_quotes
        quotes = quotes.where('date < ?', @account.playback_date) if @account.playback_date
        quote_data = [];
        previous_last_price = nil

        quotes.each do |quote|
          # Skip major spike quotes.
          previous_last_price ||= quote.last_price.to_f
          next if quote.last_price.to_f / previous_last_price > 1.015
          next if quote.last_price.to_f / previous_last_price < 0.985

          quote_data << {
            :symbol       => security.symbol,
            :last_price   => quote.last_price.to_f,
            :bid_price    => quote.bid_price.to_f,
            :ask_price    => quote.bid_price.to_f,
            :timestamp    => quote.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            :trade_volume => quote.trade_volume
          }
          previous_last_price = quote.last_price.to_f
        end
        @socket.send({
          :type => TradingApi.types[:chart_data],
          :symbol => message_data['symbol'],
          :data => quote_data
        }.to_json)
    end
  end
  
  def handle_close
    @client_data_broker.remove_client(@socket)
    puts 'Connection closed'
  end
  
  def handle_error(event)
    puts "Error: #{event.message}"
  end
end
