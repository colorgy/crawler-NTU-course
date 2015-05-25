require './config'
require 'sidekiq/api'
require 'json'

$redis = Redis.new(url: ENV['REDISTOGO_URL'])

processed ||= Sidekiq::Stats.new.processed

$root = File.dirname(__FILE__)

get '/' do
  error 401, { status: 'bad key' }.to_json if ENV['API_KEY'] != params[:key]

  workers_size = Sidekiq::Stats.new.workers_size
  if workers_size == 0 && processed == Sidekiq::Stats.new.processed
    job_id = CrawlWorker.perform_async
    return JSON.pretty_generate({status: 'task started', processed: processed})
  else
    # while running task
    if Sidekiq::Stats.new.processed == (processed + 1)
      processed = Sidekiq::Stats.new.processed
      return JSON.pretty_generate({status: 'done', processed: processed})
    else
      return JSON.pretty_generate({status: 'crawling...', processed: processed})
    end
  end
end

get '/force' do
  error 401, { status: 'bad key' }.to_json if ENV['API_KEY'] != params[:key]

  workers_size = Sidekiq::Stats.new.workers_size
  if processed == Sidekiq::Stats.new.processed
    if workers_size == 0
      job_id = CrawlWorker.perform_async(force: true)
      return JSON.pretty_generate({status: 'task started', processed: processed})

    else
      return JSON.pretty_generate({status: 'crawling...', processed: processed})
    end

  elsif Sidekiq::Stats.new.processed == (processed + 1)
    processed = Sidekiq::Stats.new.processed
    return JSON.pretty_generate({status: 'done', processed: processed})
  end

end

get '/courses.json' do
  if $redis.exists("course")
    content_type :json
    course_jsons = $redis.lrange "course", 0, -1
    return JSON.pretty_generate course_jsons.map {|d| JSON.parse(d)}
  else
    return {status: 'has no crawl data yet'}.to_json
  end
end
