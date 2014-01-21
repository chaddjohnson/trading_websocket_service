require 'bundler/setup'
require 'yaml'
require 'active_record'
require 'mysql2'
require 'protected_attributes'

DB_CONFIG = YAML::load(File.open('config/database.yml'))
ActiveRecord::Base.establish_connection(
  adapter:  'mysql2',
  host:     DB_CONFIG['host'],
  database: DB_CONFIG['database'],
  username: DB_CONFIG['username'],
  password: DB_CONFIG['password']
)

Dir['./models/*.rb'].each { |file| require file }

API_CONFIG = YAML::load_file('./config/settings.yml')
