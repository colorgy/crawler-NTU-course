web: bundle exec thin start -p $PORT -e $RACK_ENV
worker: bundle exec sidekiq -c 20 -v -r ./app.rb
