require_relative './ntu_crawler.rb'

class CrawlWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  @@crawler = NtuCrawler.new(encoding: 'big5')

  def perform(msg="crawl", force: false)
    $redis.lpush(msg, start_spider)
  end

  def expiration
    @expiration ||= 60 # 1 minute
  end

  def start_spider
    @@crawler.course
  end

end
