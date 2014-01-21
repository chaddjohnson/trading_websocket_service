require './config/application.rb'
require './lib/web_socket_service'

EventMachine.run do
  puts 'Started WebSocket server on port 4000...'
  
  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 4000, :debug => false) do |socket|
    WebSocketService.new(socket)
  end
end