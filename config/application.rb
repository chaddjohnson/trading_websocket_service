require 'bundler/setup'
require 'yaml'
require 'active_record'
require 'mysql2'
require 'protected_attributes'
require 'trading_core'

DB_CONFIG = YAML::load_file('./config/database.yml')
ActiveRecord::Base.establish_connection({
  :adapter =>  DB_CONFIG['adapter'],
  :host =>     DB_CONFIG['host'],
  :database => DB_CONFIG['database'],
  :username => DB_CONFIG['username'],
  :password => DB_CONFIG['password']
})

APP_CONFIG = YAML::load_file('./config/settings.yml')
