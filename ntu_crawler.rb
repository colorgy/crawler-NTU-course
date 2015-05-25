require 'XDDCrawler'
require 'pry'

require 'thread'
require 'thwait'

class NtuCrawler
  include XDDCrawler::ASPEssential

  DAYS = {
    "一" => 1,
    "二" => 2,
    "三" => 3,
    "四" => 4,
    "五" => 5,
    "六" => 6,
    "日" => 7,
  }

  PERIODS = {
    "1" => 1,
    "2" => 2,
    "3" => 3,
    "4" => 4,
    "@" => 5,
    "5" => 6,
    "6" => 7,
    "7" => 8,
    "8" => 9,
    "9" => 10,
    "A" => 11,
    "B" => 12,
    "C" => 13,
    "D" => 14
  }

  def initialize(*args)
    super(*args)

    @courses = []
    @search_url = "https://nol.ntu.edu.tw/nol/coursesearch/search_result.php"

    @threads = []
    @year = 103
    @term = 1
  end

  def course detail=false
    visit @search_url

    post @search_url, {
      cstype: 1,
      select_sem: "#{@year}-#{@term}",
    }

    pages_param = @doc.xpath('//select[@name="jump"]//@value').map(&:value).uniq
    pages_param.each do |query|
      sleep(1) until (Thread.list.count < (ENV['MAX_THREADS'] || 20))

      @threads << Thread.new do
        r = RestClient.get "#{@search_url}#{query}"

        doc = Nokogiri::HTML(r.force_encoding(@encoding))
        doc.xpath('/html/body/table[4]//tr[position()>1]').each do |row|
          datas = row.css('td')

          course_days = []
          course_periods = []
          course_locations = []

          # results =  [["一", "12", "請洽系所辦"], ["四", "12", "請洽系所辦"]]
          results = datas[11] && datas[11].text.scan(/(?<d>[#{DAYS.keys.join('')}])(?<p>[#{PERIODS.keys.join('')}]+)(\((?<loc>[^\)]+)\))/)
          results.each do |re|
            re[1].split("").each do |p|
              course_days << DAYS[re[0]]
              course_periods << PERIODS[p]
              course_locations << re[2]
            end
          end

          @courses << {
            serial: datas[0] && datas[0].text.power_strip,
            department: datas[1] && datas[1].text.power_strip,
            code: datas[2] && datas[2].text.power_strip,
            name: datas[4] && datas[4].text.power_strip,
            credits: datas[5] && datas[5].text.to_i,
            id: datas[6] && datas[6].text.power_strip,
            required: datas[8] && datas[8].text.include?('必'),
            lecturer: datas[9] && datas[9].text.power_strip,
            :day_1 => course_days[0],
            :day_2 => course_days[1],
            :day_3 => course_days[2],
            :day_4 => course_days[3],
            :day_5 => course_days[4],
            :day_6 => course_days[5],
            :day_7 => course_days[6],
            :day_8 => course_days[7],
            :day_9 => course_days[8],
            :period_1 => course_periods[0],
            :period_2 => course_periods[1],
            :period_3 => course_periods[2],
            :period_4 => course_periods[3],
            :period_5 => course_periods[4],
            :period_6 => course_periods[5],
            :period_7 => course_periods[6],
            :period_8 => course_periods[7],
            :period_9 => course_periods[8],
            :location_1 => course_locations[0],
            :location_2 => course_locations[1],
            :location_3 => course_locations[2],
            :location_4 => course_locations[3],
            :location_5 => course_locations[4],
            :location_6 => course_locations[5],
            :location_7 => course_locations[6],
            :location_8 => course_locations[7],
            :location_9 => course_locations[8],
          }

        end
      end
    end

    ThreadsWait.all_waits(*@threads)
    binding.pry
    puts "hello"
  end
end

class String
  def power_strip
    self.strip.gsub(/^[ |\s]*|[ |\s]*$/,'')
  end
end

NtuCrawler.new(encoding: 'big5').course
