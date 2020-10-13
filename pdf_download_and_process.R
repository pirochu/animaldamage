#鳥獣被害のPDF公開データの取得とCSV化
#As of: 2020-10-12

#----- 概要 -----

#データサイエンスという言葉が使われるようになるに伴い、
#データの機械可読性が重要視され始めていますが、
#まだWeb上におけるPDFによるデータ公開や共有が行われていることも多いです。
#このスクリプトは主に「pdftools」というパッケージを利用してPDFからのデータ取得を紹介します。

#ただ、PDFデータは取得できたとしても、その後の加工がひと手間なことが多いです。
#特にExcel上でセルの結合をして、複雑な入れ子を作っているようなファイルをPDF化してあるデータは
#かなり頑張って加工しなければなりません。

#例えば、FAOstat(http://www.fao.org/faostat/en/)のデータは、
#csv形式、1行目に項目名(変数名)、セルの結合などではなくカテゴリーなどはコード化して列にまとめている
#という点で機械可読性が高く、そのまま解析用のソフトウェアにインポートすることが可能です。

#一方、日本の政府がe-statなどで公開しているデータは、中には整備されているものもある一方で、
#紙に打ち出した時に見やすいように整えられているデータも多くあり、
#ダウンロードした後に、利用者側でさらに加工を加えないと統計解析に使えないことが多くあります。

#また、e-statに入っていない各省庁が抱えるデータの中には、PDF配布のものも多くみられます。
#ここでは、例として農水省が有する「野生鳥獣による都道府県別農作物被害状況」のPDFデータを例に取ります。
#https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/index.html

#このデータはPDF形式の配布(おそらく閲覧専用?)で、
#行の頭にも、列の左端にも、セルを結合した部分があり、一筋縄ではいきません。

#以下では、この鳥獣被害状況のデータを例として、PDFからのデータ取得から加工まで一連の動きの練習を行います。
#このスクリプトを通して、機械可読性の高いデータの作成と公開および共有が
#データサイエンスのさらなる発展にとても重要であることを学んでもらえると思います。


#----- 主な参考資料 -----

#-#-# pdftoolsパッケージ
#CRAN package document: pdftools
#https://cran.r-project.org/web/packages/pdftools/pdftools.pdf


#-#-# 農村振興局農村政策部鳥獣対策・農村環境課
#鳥獣被害対策コーナー
#https://www.maff.go.jp/j/seisan/tyozyu/higai/

#平成30年度_野生鳥獣による農作物被害状況の各都道府県公表場所
#https://www.maff.go.jp/j/seisan/tyozyu/higai/attach/pdf/index-344.pdf

#----- 各種環境設定 -----

### 環境やプロット、コンソールをクリアしたい場合は以下を実行(任意)
rm(list = ls(all=TRUE)) 　　　#グローバル環境(作成されているオブジェクトや変数)をクリア
if(dev.cur() > 1) dev.off() 　#プロット欄の図があればクリア
cat("\014") 　　　　　　　　　#コンソールのクリア

### 個人設定
#作業ディレクトリを任意のものに指定
myworkingdirectry <- "C:/Users/hsugi/GWD/z0_RWD"

### 作業ディレクトリの設定
getwd() 　　　　　　　　　#現在の作業ディレクトリを確認
setwd(myworkingdirectry)　#作業ディレクトリを設定。ディレクトリについては任意のものを設定
list.files()　　　　　　　#作業ディレクトリ内のファイルをチェックする

#----- 使用するパッケージの準備 -----

### tabulizer関係意外の必要なパッケージのインストール
# 必要なパッケージのリストを作成
# 最後のパッケージ名の後はカンマ無しでかっこを閉じることを忘れないように
lrp <- c("pdftools",    #PDFの情報やPDFのtextデータの取り出し用
         "curl",        #URLからデータを読み込むためのインターフェイス
         "tidyverse",   #データ操作と可視化のためのコアパッケージ
         "purrr",       #forループやlistの処理を簡潔に書けるようサポート。dplyrやtidyrとシナジー
         "readr",       #データ読み込み用パッケージ。type_convert()等が便利
         "tidyr",       #データフレームを縦長・横広・入れ子に変形・整形するためのツール。reshape2の改良版
         "stringr",     #Rにおいて文字列処理や操作を行うための便利パッケージ
         "dplyr")       #データフレームに対して、抽出や部分的変更、要約、ソートなどの処理を簡単に施せる

#上で作ったリストに対して、
#もしパッケージがなければインストール＆ライブラリー、入っていればライブラリーのみ

##Package installing (only if not downloaded) and library
#ptp = package to prepare
for (i in 1:length(lrp)) {
  ptp <- lrp[i]
  if(!require(ptp, character.only = TRUE)) {
    install.packages(ptp)
    library(ptp, character.only = TRUE)
  } else {
    library(ptp, character.only = TRUE)
  }
}

#----- ///// 分析本体 ///// -----

#----- 農林水産省のウェブサイトからPDFファイルを取得 -----

#農林水産省農村振興局「全国の野生鳥獣による農作物被害状況について」における公開データを使用
#https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/index.html

#curlパッケージを使ってデータを直接URLからダウンロード
#ダウンロード先のURLとダウンロードした際のファイル名を先に準備

#本当はこのURL取得も一定の規則があればfor文で簡単にリスト化できるのですが、残念ながら微妙に統一されていないので手動で
chouzyu_dmg_url <- c(
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h15/h15_sankou5.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h16/h16_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h17/h17_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h18/h18_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h19/h19_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h20/h20_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo/h21/h21_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h22/pdf/h22_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h23/h23_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h24/h24_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h25/h25_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h26/h26_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h27/pdf/h27_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/h_zyokyo2/h28/h28_sankou2.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/h_zyokyo2/h29/attach/pdf/181026-4.pdf",
  "https://www.maff.go.jp/j/seisan/tyozyu/higai/hogai_zyoukyou/attach/pdf/index-4.pdf"
)

#連番のファイル名は、paste()の中にseq()を仕込むことで作成
chouzyu_dmg_file <-  paste("chouzyu_dmg_", seq(2003, 2018, 1), ".pdf", sep = "")

#PDFデータダウンロードと作業ディレクトリへの格納
#上で作ったPDFの直接リンクのリストを上からダウンロードした上で、
#それぞれ連番のファイル名を付けてフォルダに保存することを繰り返す
for(i in 1:length(chouzyu_dmg_url)){
  
  curl::curl_download(chouzyu_dmg_url[i], chouzyu_dmg_file[i]) #curl_download(ファイルURL, ファイル名)
  
}

#----- 取得したPDFファイルの情報(作成日など)を(参考情報として)取得する -----

#pdftoolsパッケージを利用して、総ページ数とデータ作成日時を取得
#上でダウンロードした全てのファイルから情報を抜き出して、一つのデータフレームに格納->書き出し
#pdftoolsパッケージでは、バージョン情報(version)や、暗号化されているか(encrypted)、更新日(modified)なども取得可能

#空のデータフレームを作成
chouzyu_pdf_info <- NULL

#for繰り返し文を利用して、それぞれのPDFから該当データの抜き出し
for(i in 1:length(chouzyu_dmg_file)){
  
  temp_dmg <- pdf_info(chouzyu_dmg_file[i]) #各ファイルの情報を抜き出す
  
  pdf_pages <- temp_dmg$pages #総ページ数を取得
  pdf_created <- strftime(temp_dmg$created, format="%Y-%m-%d") #データ作成日時をyyyy-mm-ddの形で取得

  chouzyu_pdf_info_tmp <- c(pdf_pages, pdf_created)
  chouzyu_pdf_info <- cbind(chouzyu_pdf_info, chouzyu_pdf_info_tmp)
  
}

chouzyu_pdf_info02 <- chouzyu_pdf_info

colnames(chouzyu_pdf_info02) <- chouzyu_dmg_file
rownames(chouzyu_pdf_info02) <- c("Pages", "Created")
chouzyu_pdf_info02

write.csv(chouzyu_pdf_info02, "chouzyu_pdf_info.csv")


#----- 2017年度のpdfデータをcsvデータ化 -----

#2017年度のデータを{pdftools}パケージのpdf_text()を使って無理やり取得し、整形してcsvデータにする
text <- pdf_text(chouzyu_dmg_file[15])
text

#\n（改行）部分でベクトルを切るなど処理を行い、データフレーム化
text %>% 
  str_split('\n') %>% 
  as_tibble(.name_repair = 'unique') %>%
  
  #タイトルや補注が入っている行を削る
  slice(-c(1:7, 72:75)) %>%
  
  #各列の両端の空白を削る
  mutate(...1 = str_trim(...1, side = 'both'))  %>%
  
  #文字の間の空白で行を分ける。行全部がNAで埋まっている行を削除
  separate(col = ...1, into = as.character(c(1:65)), sep = '\\s+')  %>%
  slice(-c(4, 14, 23, 35, 37, 43, 46, 49)) %>%
  
  #列と列名を対応させていく
  select("都道府県名" = 1, 
         "被害面積(ha)_鳥獣計" = 2, "被害面積(ha)_鳥類" = 3, "被害面積(ha)_獣類" = 4, "被害面積(ha)_獣類_うちイノシシ" = 5, "被害面積(ha)_獣類_うちサル" = 6, "被害面積(ha)_獣類_うちシカ" = 7,
         "被害量(t)_鳥獣計" = 8, "被害量(t)_鳥類" = 9, "被害量(t)_獣類" = 10, "被害量(t)_獣類_うちイノシシ" = 11, "被害量(t)_獣類_うちサル" = 12, "被害量(t)_獣類_うちシカ" = 13,
         "被害金額(万円)_鳥獣計" = 14, "被害金額(万円)_鳥類" = 15, "被害金額(万円)_獣類" = 16, "被害金額(万円)_獣類_うちイノシシ" = 17, "被害金額(万円)_獣類_うちサル" = 18, "被害金額(万円)_獣類_うちシカ" = 19,
         "ex" = 20) %>% 
  
  print(n=Inf) %>%
  as.data.frame() -> text_df


#結合されていたセルの影響でずれてしまっている行を修正

for(i in c(6, 8, 15, 19, 23, 24, 26, 27, 28, 35, 43, 45, 48, 51, 53, 56)){
  text_df[i,] <- c(text_df[i, 2:20], NA)
}

#最終調整: 消えた山梨県を入れる。都府県計の行とexの列を削除
text_df[16, 1] <- "山梨県"
text_df_f <- text_df[-55, -20]
text_df_f <- filter(text_df_f, text_df_f$都道府県名 != "計")

write.csv(text_df_f, "chouzyu_dmg_2017.csv", row.names = FALSE)


#----- ///// tabulizer{}を使ったpdfファイルのcsvファイル化 ///// -----

#上で2017年のものだけpdftools{}のpdf_text()でcsvファイル化した理由は
#下で扱う、もう少し簡単にpdfをcsvファイル化できるtabulizer{}パッケージではうまく処理できなかったからです。
#残りのpdfファイルは以下でtabulizer{}とforループを用いて一気にcsvファイル化してしまいましょう
#ただし、tabulizer{}はRからJAVAが使えるようにしておく必要性があるので、
#まずはそのセットアップをMac環境とWindows環境で分けて行っていきます。

#----- tabulizerパッケージを使うための環境セットアップ -----

#tabulizerのインストール&セットアップ時の参考: PDF Scraping in R with tabulizer
#https://www.business-science.io/code-tools/2019/09/23/tabulizer-pdf-scraping.html

#tabulizerパッケージを使うためには、RからJAVAが使えるようにした上で、
#rJavaパッケージとtabulizerパッケージ、およびtabulizerjarsパッケージをインストールしておかなければなりません。

#MacとWindowsでは手順が異なりますので、以下にそれぞれをまとめました。

#----- >>> Mac環境におけるrJavaのインストールと各パッケージのインストールまで -----

###参考

#Mac環境にてRにJavaを上手くつなげられない場合
#https://github.com/rstudio/rstudio/issues/2254

#また、少し情報が古いですが、以下のまとめも参考になるかもしれません
#Run rJava with RStudio under OSX 10.10, 10.11 (El Capitan) or 10.12 (Sierra)
#https://github.com/MTFA/CohortEx/wiki/Run-rJava-with-RStudio-under-OSX-10.10,-10.11-(El-Capitan)-or-10.12-(Sierra)

#日本語におけるトラブルシューティングまとめ
#https://www.pediatricsurgery.site/entry/2018/06/21/202552


###手順


#1)以下のJava.comウェブサイトにて、JavaのMac OS X(10.7.3 version and above)をダウンロード
#https://www.java.com/en/download/manual.jsp

#2)以下のOracle.comウェブサイトにて、Java SE Development Kitの最新版をダウンロードする(macOS Installer)
#https://www.oracle.com/java/technologies/javase-downloads.html

#3)Terminalにて以下を実行(なお、Terminal上のコードは#を外して実行のこと)
#3-1)ディレクトリをダウンロードディレクトリに
#cd $HOME/Downloads

#2)Xcode Command Line Toolsを持っていなければインストール
#xcode-select --install

#3)JAVA_HOMEの設定
#/usr/libexec/java_home -V
#java -version

#4)RにJAVA_HOMEにて設定されたJAVAを使うように宣言
#sudo R CMD javareconf

#5)ターミナルを退出
#exit

#6)最後にR上で、rJavaパッケージとtabulizerパッケージ、tabulizerjarsパッケージをインストールする
install.packages("rJava")
install.packages("tabulizer")
install.packages("tabulizerjars")

#----- >>> Windows環境におけるrJavaのインストールと各パッケージのインストールまで -----

###参考

#Windows 10におけるrJavaのインストールについて
#https://cimentadaj.github.io/blog/2018-05-25-installing-rjava-on-windows-10/installing-rjava-on-windows-10/


###手順

#1)使用しているプラットフォームのBit数を確認(64-bit / 32-bit)
sessionInfo()

#2)上で確認したプラットフォームBit数に対応したものを、以下の2つのウェブサイトからそれぞれダウンロード
#それぞれダウンロードしたものを実行し、展開先は64bitなら「C:/Program Files/Java/」、32bitなら「C:/Program Files (x86)/Java/」

#a)以下のJava.comウェブサイトにて、JavaのWindows Offline(64-bit)をダウンロード
#https://www.java.com/en/download/manual.jsp

#b)以下のOracle.comウェブサイトにて、Java SE Development Kitの最新版をダウンロードする
#https://www.oracle.com/java/technologies/javase-downloads.html

#3)rJavaパッケージをインストールする
install.packages("rJava")

#4)R上で、JAVA_HOVE環境を以下のコマンドで設定する。jdk-**.*.*の部分はダウンロードしたJDKのバージョンによって変更
Sys.setenv(JAVA_HOME="C:/Program Files/Java/jdk-14.0.1/")

#5)tabulizerパッケージとtabulizerjarsパッケージをインストールする
install.packages("tabulizer")
install.packages("tabulizerjars")

#----- ダウンロードしたPDFファイルから表を取り出す -----

#tabulizerパッケージを使うために必要なものの呼び出し
library(rJava)          #tabulizerを使用するために必要
library(tabulizer)      #PDFからデータ取得するためのパッケージ
library(tabulizerjars)


#データリストと書き出し用のデータ名リストを準備
chouzyu_dmg_datalist <- paste("chouzyu_dmg_", seq(2003, 2018, 1), sep = "")
chouzyu_dmg_filelist <- paste("chouzyu_dmg_", seq(2003, 2018, 1), ".csv", sep = "")

#最終的な表の列名を準備
chouzyu_df_colnames <- c("都道府県名", "被害面積(ha)_鳥獣計", "被害面積(ha)_鳥類", "被害面積(ha)_獣類", "被害面積(ha)_獣類_うちイノシシ", "被害面積(ha)_獣類_うちサル", "被害面積(ha)_獣類_うちシカ",
                         "被害量(t)_鳥獣計", "被害量(t)_鳥類", "被害量(t)_獣類", "被害量(t)_獣類_うちイノシシ", "被害量(t)_獣類_うちサル", "被害量(t)_獣類_うちシカ",
                         "被害金額(万円)_鳥獣計", "被害金額(万円)_鳥類", "被害金額(万円)_獣類", "被害金額(万円)_獣類_うちイノシシ", "被害金額(万円)_獣類_うちサル", "被害金額(万円)_獣類_うちシカ")

#ダウンロードしたPDFの特徴分析
#共通の特徴: 表のヘッダー部分は欄外も合わせて変わらない -> データフレーム化した際に上から6行目まで削除可能
#2003~2007年度(1~5): データフレーム化した際に、都府県計の行無し、北海道と沖縄の行のズレ無し、罫線パターンの違いから6列分ほどNAの列が挟まれる
#2008~2014年度(6~12): データフレーム化した際に、都府県計の行無し、北海道と沖縄の行のズレ有り
#2015~2018年度(13~16): データフレーム化した際に、都府県計の行有り、北海道と沖縄の行のズレ有り
#2016~2018年度(14~16): 前年度比のデータが右6列に入っている -> 前年度比のデータは全てのデータから削除
#2017年度のPDFデータはtabulizerで変換不可(原因不明)

#2017年度以外の15個のPDFデータをデータフレーム化と共通処理
pref_name <- c("北海道", "青森県", "岩手県", "宮城県", "福島県", "茨城県", "千葉県", "秋田県", "山形県",
           "新潟県", "栃木県", "埼玉県", "東京都", "群馬県", "山梨県", "神奈川県", "富山県",
           "長野県", "静岡県", "石川県", "福井県", "岐阜県", "愛知県", "滋賀県", "三重県",
           "京都府", "奈良県", "和歌山県", "兵庫県", "大阪府", "鳥取県", "岡山県", "島根県",
           "広島県", "香川県", "徳島県", "愛媛県", "高知県", "山口県", "福岡県", "大分県",
           "宮崎県", "佐賀県", "熊本県", "鹿児島県", "長崎県", "沖縄県")

n_process <- c(1:14, 16)

for(i in n_process) {

  dl_selected <- chouzyu_dmg_file[i]
  
  #PDFから表を取り出す
  df0 <- extract_tables(
    file     = dl_selected,
    pages    = 1,
    guess    = TRUE,
    method   = "decide",
    encoding = "UTF-8"
  )
  
  #一番目のテーブルを取得
  df0_tbl <- df0 %>% 
    pluck(1) %>% 
    as_tibble()
  
  #上で一応as_tibble()を挟んではいるが、以降うまくデータフレームを扱うため、
  #readr::type_convert()を挟む
  df0_tbl_converted <- type_convert(df0_tbl)
  
  #一つの列の中で複数の値が入っているので、それを分割
  d_temp <- separate_rows(df0_tbl_converted, V2:V20, sep = "\r", convert = TRUE)
  str_replace_all(d_temp$V2, "\r", "")

  d_temp02 <- d_temp[-(1:6),]
  
  if(i < 6){
    
    d_temp02 <- d_temp02[, !(colnames(d_temp02) %in% c("V1", "V5", "V7", "V13", "V15", "V21", "V23"))]
    d_temp02 <- d_temp02[-55,]
    d_temp02 <- filter(d_temp02, V2 != "小計")
    
    colnames(d_temp02) <- chouzyu_df_colnames
    
  } else if (i >= 6 && i <= 12 ) {
    
    d_temp02[is.na(d_temp02$V20), 2:20] <- d_temp02[is.na(d_temp02$V20), 1:19]
    
    d_temp02 <- d_temp02[, !(colnames(d_temp02) %in% c("V1"))]
    d_temp02 <- d_temp02[-55,]
    d_temp02 <- dplyr::filter(d_temp02, V2 != "小 計")

    colnames(d_temp02) <- chouzyu_df_colnames
    
  } else if (i == 13) {
    
    d_temp02[is.na(d_temp02$V20), 2:20] <- d_temp02[is.na(d_temp02$V20), 1:19]
    
    d_temp02 <- d_temp02[, !(colnames(d_temp02) %in% c("V1"))]
    d_temp02 <- d_temp02[-55,1:19]
    d_temp02 <- dplyr::filter(d_temp02, V2 != "小 計")
    d_temp02 <- dplyr::filter(d_temp02, V2 != "合  計")
    
    colnames(d_temp02) <- chouzyu_df_colnames
    
  } else if (i > 13) {
    
    d_temp02[is.na(d_temp02$V26), 2:20] <- d_temp02[is.na(d_temp02$V26), 1:19]
    
    d_temp02 <- d_temp02[, !(colnames(d_temp02) %in% c("V1"))]
    d_temp02 <- d_temp02[-55,1:19]
    d_temp02 <- dplyr::filter(d_temp02, V2 != "小 計")
    d_temp02 <- dplyr::filter(d_temp02, V2 != "合  計")
    
    colnames(d_temp02) <- chouzyu_df_colnames
    
  }
  
  #データフレームに格納
  d_temp02$都道府県名 <- pref_name
  assign(paste("df_", chouzyu_dmg_datalist[i], sep = ""), d_temp02, env = .GlobalEnv)
  
  #データの書き出し
  filename2csv <- chouzyu_dmg_filelist[i]
  write.csv(d_temp02, filename2csv, row.names = FALSE)
  
}

#とにかく、PDFデータを相手にするのは骨が折れる。。。

#----- Script ends here -----
