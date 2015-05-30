require './app'
require 'sidekiq/web'

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  [user, password] == ["admin", ENV['API_KEY']]
end

run Rack::URLMap.new('/' => WebTaskRunner, '/sidekiq' => Sidekiq::Web)
