require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

Dir[File.dirname(__FILE__) + '/app/*.rb'].each {|file| require file }

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Status::ClientMiddleware
  end
end
