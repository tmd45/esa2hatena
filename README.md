# esa.io to Hatena Blog

esa の日報に書いた所感を、Hatena Blog の記事（下書き）にする。

## How to use

### 準備

- `$ bundle install`
- `.env.skeleton` を元に必要な token やファイルを用意する。

### 実行

```
$ bundle exec esa2qiita.rb
```

### 補足: direnv を利用する場合

[direnv](https://github.com/direnv/direnv)

```
$ echo 'dotenv ./.env' > .envrc
$ cp .env.skeleton .env
```