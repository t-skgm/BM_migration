require 'nokogiri'
require 'mechanize'
require 'csv'

result_path = "bookID.csv"
incl_org = 0

acount_m = "mail" # 自分のログイン用メールアドレスを入れる
acount_pw = "pw" # 自分のパスワードを入れる

userid = "33029"
base_url = "http://bookmeter.com"
my_url = base_url + '/u/' + userid
login_url = base_url + '/login'
bookIDs = []

agent = Mechanize.new
agent.user_agent = 'Windows IE 7'

agent.get(login_url) do |page|
  page.form_with(:action => '/login') do |form|
    formdata = {
      :mail => acount_m,
      :password => acount_pw,
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

# bookID取得　x4
list_type = ["booklist", "booklistnow", "booklisttun", "booklistpre"] # 読んだ, 読んでる, 積読, 読みたい

list_type.each do |type|
  list_url = my_url + "/" + type
  html = agent.get(list_url).content.toutf8
  page_max = $1.to_i if html =~ %r[&p=(\d+)\">最後]
  page_max = 1 if page_max == nil || page_max == ""

  (1..page_max).each do |i|
    each_list_url = list_url + "&p=" + i.to_s
    page = agent.get(each_list_url)
    doc = Nokogiri::HTML(page.content.toutf8)

    doc.xpath("//div[@id='main_left']//div[contains(concat(' ',@class,' '),' book ')]").each do |node|
      bookID = node.xpath("./div[@class='book_box_book_title']/a/@href").to_s[3..-1]
      bookIDs.push bookID
    end

    sleep(0.1)
  end
end

bookIDs.uniq!

File.open("bookID.txt", "w") do |txt|
  bookIDs.each do |id|
    txt.puts id
  end
end
