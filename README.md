## COMET-CDC Wire Stringing Status by D3.js

# 概要
「ワイヤー張り」の進行状況を確認するためのアプリケーション。ワイヤー張りは、1日約140本のペースで進み、合計19,548本で終了する。トップページには、以下７つのタブがある。

- Shift Calendar: シフト表。Googleカレンダーの埋め込み。
- Status: 張り終えたワイヤーの全体図。
- Progress: 1日ごとの張り終えたワイヤー本数等のヒストグラム。
- Tension: ワイヤー張力のヒストグラム。
- Endplate: エンドプレート間の距離、張力の日ごとの変化。
- File: チェックシート等の静的ファイル。
- Upload: XMLとCSVファイルのアップロードフォーム。

# 仕様

- XML、CSVファイルのアップロード。
- XMLファイルには、ワイヤー毎に、張られた日付や張力等の項目が定義されている。
- CSVファイルは、エンドプレート間距離、テンションバー情報、温度・湿度情報の３種類。
- XML,CSVファイルはサーバーにバックアップとして保存しておく。
- XMLアップロード時に、その日の情報（１日に張り終えたワイヤー総数、張力の要求を満たさない総数）とその日までの情報（ワイヤー張りが完了した総数、ワイヤー張りの終了日など）を計算し、その結果をJSON形式でサーバーに保存する。
- ブラウザからJSONを元に、各ヒストグラムを生成し表示する。

# 実装
- サーバー: [Heroku] (https://www.heroku.com/home)
- サーバーアプリ: [Sinatra] (http://www.sinatrarb.com/intro-ja.html)
- ストレージ: [AWS-S3] (https://aws.amazon.com/jp/s3/)
- 認証: [Amazon-Cognito] (https://aws.amazon.com/jp/cognito/)
- ヒストグラム生成: [D3.js] (http://d3js.org)
- データ圧縮: [zip.js] (https://gildas-lormeau.github.io/zip.js/)

# How to

- ローカルでのテスト

```
$ foreman start
```

- ステージング環境の構築

```
$ heroku fork --from comet-cdc --to comet-cdc-staging
$ git remove --v
$ git remote add staging https://git.heroku.com/comet-cdc-staging.git
$ git push staging staging:master --force
```

- CoffeeScriptの自動コンパイル

```
$ coffee -wc public/js/read.coffee
```

