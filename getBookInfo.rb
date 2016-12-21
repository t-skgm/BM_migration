require 'nokogiri'
require 'mechanize'
require 'csv'

if ARGV[0] == nil
  STDERR.puts "set filename"
else
  bookIDtxt = ARGV[0]
end
result_path = bookIDtxt + "_result.csv"
category = "bookmeter"
incl_org = 0
w_service = 0
=begin
0=migr
1=booklog
2=メディアマーカー (ISBN/ASIN, コメント)
3=ビブリア (v.0.4.0)
100=debug
=end
userid = "33029" #わからなければ入れない

base_url = "http://bookmeter.com"
my_url = base_url + '/u/' + userid
login_url = base_url + '/login'
books = []

agent = Mechanize.new
agent.user_agent = 'Mac Safari'

agent.get(login_url) do |page|
  page.form_with(:action => '/login') do |form|
    formdata = {
      :mail => "mail", # 自分のログイン用メールアドレスを入れる
      :password => "pw",  # 自分のパスワードを入れる
    }
    form.field_with(:name => 'mail').value = formdata[:mail]
    form.field_with(:name => 'password').value = formdata[:password]
  end.submit
end

unless userid == nil || userid == ""
  page = agent.get(base_url + "/home")
  doc = Nokogiri::HTML(page.content.toutf8)
  userid = doc.xpath("//div[@class='navi_box']/a[text()='マイページ']/@href").to_s[3..-1]
end

bookIDs = CSV.read(bookIDtxt)
bookIDs.flatten!

unless incl_org == 1
  bookIDs_org = bookIDs.select {|id| /org/ =~ id}
  bookIDs = bookIDs.reject {|x| /org/ =~ x}
end

book_n = bookIDs.length - 1

# 本ごとの情報取得
(0..book_n).each do |i|
  each_book_url = base_url + "/b/" + bookIDs[i]
  page = agent.get(each_book_url)
  doc = Nokogiri::HTML(page.content.toutf8)

  ss, st = [],[]
  doc.xpath("//div[@class='book_add_button_sprite']/div/a/@class").each {|node| ss.push(node.text)}
  st.push(4) if ss.find {|t| t == "book_add_reread"}
  st.push(3) if ss.find {|t| t == "book_add_now_del"}
  st.push(2) if ss.find {|t| t == "book_add_tun_del"}
  st.push(1) if ss.find {|t| t == "book_add_pre_del"}
  # 読んだ < 読んでる < 積読 < 読みたい

  title = doc.xpath("//h1[@id='title']/text()").to_s
  author = doc.xpath("//a[@id='author_name']/text()").to_s
  review = doc.xpath("//div[@class='book_edit_area_body']/textarea[@name='comment']/text()").to_s

  rf = doc.xpath("//input[@name='fumei']/@checked").to_s
  unless rf == "checked" #「不明」にチェックマークが入っていない
    ry = format("%02d",  doc.xpath("//select[@id='read_date_y']/option[1]/@value").to_s.to_i)
    rm = format("%02d",  doc.xpath("//select[@id='read_date_m']/option[1]/@value").to_s.to_i)
    rd = format("%02d",  doc.xpath("//select[@id='read_date_d']/option[1]/@value").to_s.to_i)
  else
    ry = "0000"
    rm = rd = "00"
  end

  tag = doc.xpath("//div[@class='book_edit_area_body']/input[@name='category']/@value").to_s.gsub("　",",").gsub(/,\z/,"")
  rrank = $1 if tag =~ /☆(\d)/
  memo = tag + " (読書メーターから移行)" #コメントを取得して入れたいが難しそう

  books[i] = {
    bookID: bookIDs[i], #ASIN
    title: title,
    author: author,
    rrank: rrank, #(1-5)
    st: st, #(1-4) 4読んだ 3読んでる 2積読 1読みたい
    review: review,
    tag: tag, #カンマ区切り
    memo: memo,
    ry: ry, rm: rm, rd: rd
  }
  sleep(0.5)
end


#出力

case w_service

when 0 #migr
  out = CSV.open(result_path, "w:utf-8", force_quotes: true)
  (0..book_n).each do |i|
    l = []
    books[i].each_value{|v| l.push(v)}
    out << l
  end
  out.close
  puts("result.csv を書き出しました。")

when 1 #booklog
  fn = (bookIDs.length / 100).to_i
  #100ずつ分けた方がいい？
  (0..fn).each do |j|
    out = CSV.open(j.to_s + result_path, "w:windows-31j", force_quotes: true)
    b = j * 100
    b + 99 <= book_n ? e = b + 99 : e = book_n - b
    (b..e).each do |i|
      rdate = "#{books[i][:ry]}-#{books[i][:rm]}-#{books[i][:rd]} 00:00:00"
      case books[i][:st].max
      when 4 then status = "読み終わった"
      when 3 then status = "いま読んでる"
      when 2 then status = "積読"
      when 1 then status = "読みたい"
      else status = ""
      end
      out << ["1", books[i][:bookID], "", category, books[i][:rrank], status, books[i][:review], books[i][:tag], books[i][:memo], rdate, rdate]
      puts "#{i+1}冊取得"
    end
    out.close
    puts("#{j}result.csv を書き出しました。")
  end

when 2 #mediamarker
  fn = (bookIDs.length / 100).to_i
  (0..fn).each do |j|
    out = CSV.open(j.to_s + result_path, "w:windows-31j", force_quotes: true)
    b = j * 100
    b + 99 <= book_n ? e = b + 99 : e = book_n - b
    (b..e).each do |i|
      rdate = "読了: #{books[i][:ry]}年#{books[i][:rm]}月#{books[i][:rd]}日"
      t = [books[i][:st], books[i][:review], books[i][:memo], rdate].join(", ")
      out << [books[i][:bookID], t]
    end
    out.close
    puts("#{i}result.csv を書き出しました。")
  end

when 3 #biblia
  out = CSV.open(result_path, "w:utf-8", force_quotes: true)
  ndate = Time.now.strftime("%D")
  (0..book_n).each do |i|
    rdate = "#{books[i][:ry]}/#{books[i][:rm]}/#{books[i][:rd]}"
    case books[i][:st].max
    when 4, 3 ,2 then status = 0
    when 1 then status = 1
    else status = 1
    end
    books[i][:rrank] == "" || books[i][:rrank] == nil ? rrank = 0 : rrank = books[i][:rrank].to_i

    out << [books[i][:title], "", books[i][:author], "", "", "", rdate, books[i][:memo], books[i][:review], "", "", ndate, status, rrank]
    #タイトル, タイトル仮名(※未使用), 著者, 著者仮名(※未使用), 出版社, ISBN-13, 日付(yyyy/MM/dd), メモ, 感想, 表紙画像URL, 楽天商品リンク, データ登録日(yyyy/mm/dd), 本棚(0)/読みたい(1), 星評価(0〜5)
    #http://webservice.rakuten.co.jp/api/bookstotalsearch/をたたけば書影なども取れそう
    out.close
  end
  puts("result.csv を書き出しました。")

when 100 #debug
  p books[1]

else
  puts "wrong service num"
end
