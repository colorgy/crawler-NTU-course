require 'thread'
require 'thread/pool'
require 'thwait'
require 'digest'

class NtuCourseCrawler
  include CrawlerRocks::DSL

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

  def initialize year: current_year, term: current_term, update_progress: nil, after_each: nil

    @search_url = "https://nol.ntu.edu.tw/nol/coursesearch/search_result.php"
    @base_url = "https://nol.ntu.edu.tw/nol/coursesearch/"

    @year = year
    @term = term
    @update_progress_proc = update_progress
    @after_each_proc = after_each

    @encoding = 'big5'
  end

  def courses details: false, max_detail_count: 20_000
    @courses = []
    @threads = []

    # 重設進度
    @update_progress_proc.call(progress: 0.0) if @update_progress_proc

    visit @search_url

    puts "post search_url"
    post @search_url, {
      cstype: 1,
      select_sem: "#{@year}-#{@term}",
    }

    pool = Thread.pool(ENV['MAX_THREADS'] && ENV['MAX_THREADS'].to_i || 20)

    pages_param = @doc.xpath('//select[@name="jump"]//@value').map(&:value).uniq
    @course_pages_processed_count = 0
    @course_pages_count = pages_param.count

    pages_param.each do |query|
      pool.process(query) do
      # sleep(1) until (
      #   @threads.delete_if { |t| !t.status };  # remove dead (ended) threads
      #   @threads.count < (ENV['MAX_THREADS'] || 20)
      # )

      # @threads << Thread.new do
        puts "get page url"
        r = RestClient.get("#{@search_url}#{query}")

        puts "parse page"
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

          name = datas[4] && datas[4].text.power_strip
          lecturer = datas[9] && datas[9].text.power_strip
          department = datas[1] && datas[1].text.power_strip
          url = datas[4] && !datas[4].css('a').empty? && URI.encode("#{@base_url}#{datas[4].css('a')[0][:href]}")
          id = datas[6] && datas[6].text.power_strip.gsub(/\s/, '')
          department_code = Hash[URI.decode_www_form(url)]["dpt_code"]

          code = [@year, @term, id, department_code].join('-')

          course = {
            year: @year,
            term: @term,
            serial: datas[0] && datas[0].text.power_strip,
            department: department,
            department_code: department_code,
            number: datas[2] && datas[2].text.power_strip,
            code: code,
            name: name,
            credits: datas[5] && datas[5].text.to_i,
            id: id,
            required: datas[8] && datas[8].text.include?('必'),
            lecturer: lecturer,
            day_1: course_days[0],
            day_2: course_days[1],
            day_3: course_days[2],
            day_4: course_days[3],
            day_5: course_days[4],
            day_6: course_days[5],
            day_7: course_days[6],
            day_8: course_days[7],
            day_9: course_days[8],
            period_1: course_periods[0],
            period_2: course_periods[1],
            period_3: course_periods[2],
            period_4: course_periods[3],
            period_5: course_periods[4],
            period_6: course_periods[5],
            period_7: course_periods[6],
            period_8: course_periods[7],
            period_9: course_periods[8],
            location_1: course_locations[0],
            location_2: course_locations[1],
            location_3: course_locations[2],
            location_4: course_locations[3],
            location_5: course_locations[4],
            location_6: course_locations[5],
            location_7: course_locations[6],
            location_8: course_locations[7],
            location_9: course_locations[8],
            url: url
          }

          @courses << course

          # callbacks
          @after_each_proc.call(course: course) if @after_each_proc
          # update the progress
          @update_progress_proc.call(progress: @course_pages_processed_count.to_f / @course_pages_count.to_f) if @update_progress_proc
          @course_pages_processed_count += 1
        end # each tr row
      end # Thread.new do
    end # pages_param.each

    pool.shutdown
    ThreadsWait.all_waits(*@threads)
    puts "done!"
    @courses
  end # def course

  def current_year
    (Time.now.month.between?(1, 7) ? Time.now.year - 1 : Time.now.year)
  end

  def current_term
    (Time.now.month.between?(2, 7) ? 2 : 1)
  end
end

class String
  def power_strip
    self.strip.gsub(/^[ |\s]*|[ |\s]*$/,'')
  end
end
