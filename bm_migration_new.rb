require 'nokogiri'
require 'mechanize'
require 'csv'
require 'json'
# require 'robotex' #いる？

# リニューアル対応版、未完成！

userid = ''
base_url = 'https://elk.bookmeter.com'
my_url = base_url + '/users/' + userid
login_url = base_url + '/login'
list_type = ["read", "reading", "stacked", "wish"] # 読んだ, 読んでる, 積読, 読みたい
agent = Mechanize.new
agent.user_agent_alias = 'Windows IE 7'


class GetBookInfo

    def initialize(_my=1, _mail, _pw, _w_org＝1)
        mys = _my # 1=>自分のアカウント 0=>他人の
        mail = _mail
        pw = _pw
        w_org = _w_org # 1=>オリジナル含む 0=>含まない
    end

    def getBookID
        list_type.each do |type|
            list_url = my_url + '/books/' + type
            _page = agent.get(list_url)
            page_max = $1.to_i if _page.body =~ /&p=(\d+)\">最後/
            page_max = 1 if page_max == nil || page_max == ''

            (1..page_max).each do |i|
                each_list_url = list_url + '&p=' + i.to_s
                page = agent.get(each_list_url)
                page.search("//div[@class='thumbnail__cover']/a/@href").each do |node| # 1つしか返さない？
                    bID = node.to_s[8..-1]
                    bIDs.push(bID)
                end
                sleep(0.1)
            end
        end
        bIDs.uniq
    end

    class IDtoInfo(bookIDs)

        books = []
        bookIDs.flatten!
        unless _w_org == 1
            bookIDs_org = bookIDs.select {|id| /org/ =~ id}
            bookIDs = bookIDs.reject {|x| /org/ =~ x}
        end
        book_n = bookIDs.length - 1

        # 本ごとの情報取得
        (0..book_n).each do |i|
            each_book_url = base_url + '/books/' + bookIDs[i]
            page = agent.get(each_book_url)

            ss, st = [],[]
            page.search("//section[@class='sidebar__group']/div[2]/ul/li/@class").each {|node| ss.push(node.text)} #ここもひとつずつ？
            st.push(4) if ss =~ /active/
            st.push(3) if ss =~ /active/
            st.push(2) if ss =~ /active/
            st.push(1) if ss =~ /active/ #考えとく
            # 読んだ < 読んでる < 積読 < 読みたい

            _bookdata = page.search("//div[@class='action__edit']/div/@data-model").gsub(/&quot;/,'"')
            bookdata = JSON.parse(_bookdata)

            title = 
            author = page.search("//ul[@class='header__authors']/li/a/text()").to_s
            date = bookdata[:date] # 不明のとき調べる
            ry = date[0..-1].to_i
            rm = date[5..-1].to_i
            rd = date[8..-1].to_i

            # rf = page.search("//input[@name='fumei']/@checked").to_s
            # unless rf == "checked" #「不明」にチェックマークが入っていない
            #    ry = format("%02d", page.search("//select[@id='read_date_y']/option[1]/@value").to_s.to_i)
            #    rm = format("%02d", page.search("//select[@id='read_date_m']/option[1]/@value").to_s.to_i)
            #    rd = format("%02d", page.search("//select[@id='read_date_d']/option[1]/@value").to_s.to_i)
            # else
            #     ry = "0000"
            #     rm = rd = "00"
            # end

            tag = bookdata["bookcase"].to_a
            rrank = $1 if tag =~ /☆(\d)/
            memo = tag.to_s + " (from #{each_book_url})" #コメントを取得して入れたいが難しそう

            books[i] = {
                bookID: bookIDs[i], #ASIN ISBN-13にしたいが…。
                title: bookdata["book"]["title"],
                author: author,
                page: bookdata["pages"],
                cover: bookdata["book"]["image_url"],
                review: bookdata["review"]["text"],
                netabare: bookdata["review"]["is_netabare"],
                rrank: rrank, #(1-5)
                st: st, #(1-4) 4読んだ 3読んでる 2積読 1読みたい
                tag: tag, #array
                memo: memo,
                ry: ry, rm: rm, rd: rd
            }
            sleep(0.5)
        end

        books
    end

    def LoginBM # ログインで関数わける？
        agent.get(login_url) do |page|
            page.form_with(:action => '/login') do |form|
                form.field_with(:name => 'mail').value = mail
                form.field_with(:name => 'password').value = pw
            end.submit
        end

        if userid == nil || userid == ""
            page = agent.get(base_url + "/home")
            userid = page.search("//a[@class='account__personal']/@href").to_s[8..-1]
        end

    end


    def ConvInfo(books, service)
    # 0=生データ 1=booklog 2=メディアマーカー (ISBN/ASIN, コメント) 3=ビブリア(v.0.4.0) 100=debug
    # out に一行一レコードで入れて outを返す。@result で結果読めるようにする
    case service

    when 0 #migr
    out = []
    (0..book_n).each do |i|
        l = []
        books[i].each_value{|v| l.push(v)}
    end
    return out

    when 1, "booklog" #booklog
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

    when 2, "mediamarker" #mediamarker
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

    when 3, "biblia" #biblia
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

    when 100, "debug" #debug
        p books[1]

    else
        puts "wrong service num"
    end

    end

end

MyBookInfo = GetBookInfo.new("my", "mail", "pw", "all")
MyBookInfo.LoginBM()
MyBookID = MyBookInfo.getBookID
MyInfo = MyBookInfo.IDtoInfo(MyBookID)

csv = open(CSV)
csv = MyBookInfo.ConvInfo(MyInfo, "booklog")
close
