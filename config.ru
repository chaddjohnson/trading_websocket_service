require './config/application.rb'
require 'trading_core/client_data_broker'
require './lib/web_socket_service'

account = TradingCore::Account.find_by_token(APP_CONFIG['streaming_account_token'])
client_data_broker = TradingCore::ClientDataBroker.new(account.streamer, TradingCore::WatchListSecurity.all_symbols)

while true do
  EventMachine.run do
    puts 'Started WebSocket service on port 4000...'

    client_data_broker.start

    EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 4000, :debug => false) do |socket|
      WebSocketService.new(socket, client_data_broker)
    end
  end

  account.streamer.stop
end
