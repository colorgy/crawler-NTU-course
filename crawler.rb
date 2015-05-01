require 'nokogiri'
require 'json'
require 'rest_client'
require 'iconv'
require 'ruby-progressbar'
require 'uri'

ic = Iconv.new("utf-8//translit//IGNORE","big5")
start_url = "https://nol.ntu.edu.tw/nol/coursesearch/search_result.php?alltime=yes&allproced=yes&cstype=1&csname=&current_sem=103-2&op=stu&startrec=0"
search_url = "https://nol.ntu.edu.tw/nol/coursesearch/search_result.php"
base_url = "https://nol.ntu.edu.tw/nol/coursesearch/"

r = RestClient.get start_url
doc = Nokogiri::HTML(ic.iconv(r.to_s))
pages = doc.css('select[name="jump"]')[0].css('option').map {|l| l['value']}

deps = JSON.parse(File.read('department.json'))

courses = []
error_urls = []
redos = 0
progress = ProgressBar.create(:title => "Page", :total => pages.length)
pages.each_with_index do |page_link, index|
  begin
    r = RestClient.get "#{search_url}#{page_link}"
  rescue Exception => e
    if redos == 5
      redos = 0
      error_urls << "#{search_url}#{page_link}"
      next
    else
      sleep(5)
      redos += 1
      redo
    end
  end

  doc = Nokogiri::HTML(ic.iconv(r.to_s))
  courses_table = doc.css('table[border="1"]').last
  rows = courses_table.css('tr:not(:first-child)')

  row_progress = ProgressBar.create(:title => "Row", :total => rows.length)
  rows.each_with_index do |row, i|
    serial_number = row.css('td')[0].text.strip # 流水號
    target = row.css('td')[1].text.strip # 授課對象
    course_number = row.css('td')[2].text.strip # 課號
    # 班次的英文到底怎麼說，然後班次到底是啥...
    order = row.css('td')[3].text.strip
    course_name = row.css('td')[4].text.strip if row.css('td').count != 0
    begin
      detail_url = "#{base_url}#{row.css('td')[4].css('a')[0]['href']}" if row.css('td').count != 0 && row.css('td')[4].css('a').count != 0
    rescue Exception => e
      File.open('prog.json', 'w') {|f| f.write(JSON.pretty_generate(courses))}
    end

    begin
      credits = Integer row.css('td')[5].text.strip
    rescue Exception => e
      credits = row.css('td')[5].text.strip
      File.open('prog.json', 'w') {|f| f.write(JSON.pretty_generate(courses))}
    end

    course_id = row.css('td')[6].text.strip # 課程識別碼
    full_semester = row.css('td')[7].text.strip == '全年'
    required = row.css('td')[8].text.strip == '必修'
    lecturer = row.css('td')[9].text.strip
    take_option = row.css('td')[10].text.strip

    time_loc = {}
    match = row.css('td')[11].text.strip.scan(/[一二三四五六][\dABCD@]+/)
    locs = row.css('td')[11].text.strip.scan(/\((?<loc>[^\(\)]+)\)/)
    locs_link = !row.css('td')[11].css('a').empty? ? row.css('td')[11].css('a').map {|k| k['href']} : Array.new(match.length) { nil }
    (0..match.length-1).each do |i|
      begin
        time_loc.merge!({
          "#{match[i][0]}" => [match[i][1..-1].split(''), locs[i].first, locs_link[i]]
        })
      rescue
        time_loc = row.css('td')[11].text.strip
      end
    end

    limitations = row.css('td')[12].text.strip
    notes = row.css('td')[13].text.strip
    course_website = !row.css('td')[15].css('a').empty? ? row.css('td')[15].css('a')[0]['href'] : nil

    book ||= nil
    ref ||= nil
    begin
      r = RestClient.get URI.encode(detail_url)
      doc = Nokogiri::HTML(ic.iconv(r.to_s))
      book = doc.css('td tr:contains("指定閱讀")').css('td').last.text unless doc.css('td tr:contains("指定閱讀")').empty?
      ref = doc.css('td tr:contains("參考書目")').css('td').last.text unless doc.css('td tr:contains("參考書目")').empty?
    rescue Exception => e
    end

    # start about detail page
    # begin
    #   r = RestClient.get URI.encode(detail_url)
    #   doc = Nokogiri::HTML(ic.iconv(r.to_s))
    #   book_row = doc.css('td tr:contains("參考書目")')
    #   if book_row.count != 0
    #     book = book_row.css('td').last.text
    #   else
    #     book = nil
    #   end
    # rescue Exception => e
    #   book = nil
    # end

    department_code ||= nil
    deps.each do |dep|
      if target == dep["department"]
        department_code = dep["code"]
      end
    end

    courses << {
      :serial_number => serial_number,
      :target => target,
      :number => course_number,
      :order => order,
      :url => detail_url,
      :credits => credits,
      :code => course_id,
      :full_semester => full_semester,
      :required => required,
      :lecturer => lecturer,
      :take_option => take_option,
      :time_location => time_loc,
      :limitations => limitations,
      :note => notes,
      :website => course_website,
      :name => course_name,
      :book => book,
      :department_code => department_code,
      :reference => ref
    }
    row_progress.increment
  end
  progress.increment
end

File.open('courses.json', 'w') {|f| f.write(JSON.pretty_generate(courses))}
