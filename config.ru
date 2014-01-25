require './config/application.rb'
require 'trading_core/client_data_broker'
require './lib/web_socket_service'

EventMachine.run do
  account = TradingCore::Account.find_by_token(APP_CONFIG['streaming_account_token'])
  client_data_broker = TradingCore::ClientDataBroker.new(account.streamer, TradingCore::WatchListSecurity.all_symbols)
  client_data_broker.start

  puts 'Started WebSocket service on port 4000...'

  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 4000, :debug => false) do |socket|
    WebSocketService.new(socket, client_data_broker)
  end
end
