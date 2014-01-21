#require "#{File.dirname __FILE__}/../../config/environment" 
require './config/application.rb'
require 'em-websocket'
require 'json'
require './lib/trading_api/base'

class WebSocketService
  def initialize(socket)
    @socket = socket

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
        account = ::Account.find_by_token(message_data['token'])
        if !account
          response_data = {
            :type => TradingApi.types[:login],
            :data => { :logged_in => false }
          }
          @socket.send(response_data.to_json)
          @socket.stop
        end
        
        # Get a reference to the API client.
        @api = account.api
        @streamer = account.streamer
        
        # Now that we're logged in, make this class observe API changes.
        @api.add_observer(self)
        
        # Send success response
        response_data = {
          :type => TradingApi.types[:login],
          :data => { :logged_in => true }
        }
        @socket.send(response_data.to_json)
      
      when TradingApi.types[:quotes]
        quotes = @api.quotes(message_data['symbols'])
        response_data = {
          :type => TradingApi.types[:quotes],
          :data => quotes
        }
        @socket.send(response_data.to_json)
        
      when TradingApi.types[:stream_quotes]
        quote_callback = lambda do |callback_data|
          response_data = {
            :type => TradingApi.types[:stream_quotes],
            :data => callback_data
          }
          @socket.send(response_data.to_json)
          
          # Record history (only in live mode)
          # ...
        end
        @streamer.stream_quotes(message_data['symbols'], quote_callback)
        
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

      when TradingApi.types[:chart]
        # Retrieve all available stock data for the given security.
        security = Security.where(:symbol => message_date['symbol']).first
        quotes = security.historical_quotes
        quotes = quotes.where('date < ?', @account.playback_date) if @account.playback_date
        quote_data = [];

        quotes.each do |quote|
          quote_data << {
            :symbol       => security.symbol,
            :timestamp    => Time.now.getutc.strftime('%Y-%m-%d %H:%M:%S'),
            :last_price   => quote.last_price.to_f,
            :bid_price    => quote.bid_price.to_f,
            :ask_price    => quote.bid_price.to_f,
            :trade_volume => quote.trade_volume
          }
        end

        @socket.send({
          :type => TradingApi.types[:chart],
          :data => quote_data
        })
    end
  end
  
  def handle_close
    @streamer.stop
    puts 'Connection closed'
  end
  
  def handle_error(event)
    puts "Error: #{event.message}"
  end
end