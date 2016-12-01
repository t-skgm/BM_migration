require 'nokogiri'
require 'mechanize'
require 'csv'
# require 'robotex' #いる？

class GetBookInfo

    def initialize(_my=1, _mail, _pw, _w_org＝１)
        mys = _my #1=>自分のアカウント 0=>他人の
        mail = _mail
        pw = _pw
        w_org = _w_org # 1=>オリジナル含む 0=>含まない
    end

    def getBookID
        list_type.each do |type|
            list_url = my_url + "/" + type
            _page = agent.get(list_url).content.toutf8
            page_max = $1.to_i if _page.body =~ %r[&p=(\d+)\">最後]
            page_max = 1 if page_max == nil || page_max == ""

            (1..page_max).each do |i|
                each_list_url = list_url + "&p=" + i.to_s
                page = agent.get(each_list_url)
                page.search("//div[@id='main_left']//div[contains(concat(' ',@class,' '),' book ')]").each do |node| # 1つしか返さない？
                    bID = node.search("./div[@class='book_box_book_title']/a/@href").to_s[3..-1]
                    bIDs.push bID
                end
                sleep(0.1)
            end
        end
        bIDs.uniq
    end

    def IDtoInfo

        def initialize(_bookIDs)
            bookIDs = _bookIDs
        end

        books = []
        bookIDs.flatten!
        unless _w_org == 1
            bookIDs_org = bookIDs.select {|id| /org/ =~ id}
            bookIDs = bookIDs.reject {|x| /org/ =~ x}
        end
        book_n = bookIDs.length - 1

        # 本ごとの情報取得
        (0..book_n).each do |i|
            each_book_url = base_url + "/b/" + bookIDs[i]
            page = agent.get(each_book_url)

            ss, st = [],[]
            page.search("//div[@class='book_add_button_sprite']/div/a/@class").each {|node| ss.push(node.text)}
            st.push(4) if ss.find {|t| t == "book_add_reread"}
            st.push(3) if ss.find {|t| t == "book_add_now_del"}
            st.push(2) if ss.find {|t| t == "book_add_tun_del"}
            st.push(1) if ss.find {|t| t == "book_add_pre_del"}
            # 読んだ < 読んでる < 積読 < 読みたい

            title = page.search("//h1[@id='title']/text()").to_s
            author = page.search("//a[@id='author_name']/text()").to_s
            review = page.search("//div[@class='book_edit_area_body']/textarea[@name='comment']/text()").to_s

            rf = page.search("//input[@name='fumei']/@checked").to_s
            unless rf == "checked" #「不明」にチェックマークが入っていない
                ry = format("%02d", page.search("//select[@id='read_date_y']/option[1]/@value").to_s.to_i)
                rm = format("%02d", page.search("//select[@id='read_date_m']/option[1]/@value").to_s.to_i)
                rd = format("%02d", page.search("//select[@id='read_date_d']/option[1]/@value").to_s.to_i)
            else
                ry = "0000"
                rm = rd = "00"
            end

            tag = page.search("//div[@class='book_edit_area_body']/input[@name='category']/@value").to_s.gsub("　",",").gsub(/,\z/,"")
            rrank = $1 if tag =~ /☆(\d)/
            memo = tag + " (読書メーターから移行)" #コメントを取得して入れたいが難しそう

            books[i] = {
                bookID: bookIDs[i], #ASIN ISBN-13にしたいが…。
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

        books
    end

    userid = ""
    base_url = "http://bookmeter.com"
    my_url = base_url + '/u/' + userid
    login_url = base_url + '/login'
    list_type = ["booklist", "booklistnow", "booklisttun", "booklistpre"] # 読んだ, 読んでる, 積読, 読みたい

    # ログインで関数わける？
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows IE 7'
    agent.get(login_url) do |page|
        page.form_with(:action => '/login') do |form|
            form.field_with(:name => 'mail').value = mail
            form.field_with(:name => 'password').value = pw
        end.submit
    end

    unless userid == nil || userid == ""
        page = agent.get(base_url + "/home")
        userid = page.at("//a[text()='マイページ']/@href").to_s[3..-1]
    end

    # BookID = getBookID.new

end

class ConvInfo

    def initialize(_service = 0)
        service = _service
        # 0=生データ 1=booklog 2=メディアマーカー (ISBN/ASIN, コメント) 3=ビブリア(v.0.4.0) 100=debug
    end
    # out に一行一レコードで入れて outを返す。@result で結果読めるようにする
    case service

    when 0 #migr
    out = []
    (0..book_n).each do |i|
        l = []
        books[i].each_value{|v| l.push(v)}
    end
    return out

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

end

# MyBookInfo = GetBookInfo.new("my", "mail", "pw", "all")
# MyBookInfo.getList(MyBookID)

# csv = open(CSV)
# csv = ConvInfo(MyBookInfo, "booklog", "no_org")
# close