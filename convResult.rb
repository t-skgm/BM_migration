require 'csv'

ipt_path = "result_all.csv"
category = "bookmeter"

if ARGV[0] == nil
  STDERR.puts "set service num"
else
  w_service = ARGV[0].to_i
end

class String
  def sjisable
    str = self
    #変換テーブル上の文字を下の文字に置換する
    from_chr = "\u{301C 2212 00A2 00A3 00AC 2013 2014 2016 203E 00A0 00F8 203A}"
    to_chr   = "\u{FF5E FF0D FFE0 FFE1 FFE2 FF0D 2015 2225 FFE3 0020 03A6 3009}"
    str.tr!(from_chr, to_chr)
    #変換テーブルから漏れた不正文字は?に変換し、さらにUTF8に戻すことで今後例外を出さないようにする
    str = str.encode("Windows-31J","UTF-8",:invalid => :replace,:undef=>:replace).encode("UTF-8","Windows-31J")
  end
end #http://qiita.com/yugo-yamamoto/items/0c12488447cb8c2fc018


=begin

0=migr
1=booklog
2=メディアマーカー (ISBN/ASIN, コメント)
3=ビブリア (v.0.4.0)
100=debug

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

=end

books = CSV.table(ipt_path, encoding: "UTF-8")
book_n = books.length - 1

#出力

case w_service

when 0 #migr
  result_path = "result_migr.csv"
  out = CSV.open(result_path, "w:utf-8", force_quotes: true)
  (0..book_n).each do |i|
    l = []
    books[i].each_value{|v| l.push(v)}
    out << l
  end
  out.close
  puts("result.csv を書き出しました。")

when 1 #booklog
  result_path = "result_bl.csv"
  fn = (books.length / 100).to_i
  #100ずつ分けた方がいい？
  (0..fn).each do |j|
    nu = "%02d" % j
    out = CSV.open( nu + result_path, "w:windows-31j", force_quotes: true)
    b = j * 100
    b + 99 <= book_n ? e = b + 99 : e = book_n - b
    (b..e).each do |i|
      rm = "%02d" % books[i][:rm]
      rd = "%02d" % books[i][:rd]
      rdate = "#{books[i][:ry]}-#{rm}-#{rd} 00:00:00"
      st = eval(books[i][:st])
      case st.max
      when 4 then status = "読み終わった"
      when 3 then status = "いま読んでる"
      when 2 then status = "積読"
      when 1 then status = "読みたい"
      else status = ""
      end
      out << ["1", books[i][:bookid], "", category, books[i][:rrank], status, books[i][:review].sjisable, books[i][:tag].sjisable, books[i][:memo].sjisable, rdate, rdate]
    end
    out.close
    puts("#{nu}#{result_path}を書き出しました。(#{j}/#{fn})")
  end

when 2 #mediamarker [ISBN/ASIN,コメント]
  result_path = "result_mm.csv"
  fn = (books.length / 100).to_i
  (0..fn).each do |j|
    nu = "%02d" % j
    out = CSV.open(nu + result_path, "w:windows-31j", force_quotes: true)
    b = j * 100
    b + 99 <= book_n ? e = b + 99 : e = book_n - b
    (b..e).each do |i|
      rm = "%02d" % books[i][:rm]
      rd = "%02d" % books[i][:rd]
      rdate = "読了: #{books[i][:ry]}年#{rm}月#{rd}日"
      t = [books[i][:st], books[i][:review], books[i][:memo], rdate].join(", ").sjisable
      out << [books[i][:bookid], t]
    end
    out.close
    puts("#{i}#{result_path}を書き出しました。")
  end

when 3 #biblia
  result_path = "result_bib.csv"
  out = CSV.open(result_path, "w:utf-8", force_quotes: true)
  ndate = Time.now.strftime("%D")
  (0..book_n).each do |i|
    rdate = "#{books[i][:ry]}/#{books[i][:rm]}/#{books[i][:rd]}"
    st = eval(books[i][:st])
    case st.max
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
  puts("#{result_path}を書き出しました。")

when 100 #debug
  p books[6]
  
else
  puts "wrong service num"
end
