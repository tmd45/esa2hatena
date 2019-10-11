# frozen_string_literal: true

require 'atomutil'
require 'date'
require 'esa'
require 'json'
require 'pp'

module Esa
  # 自分の日報から "所感" を抜き出す
  class RemarksExporter
    attr_reader :client

    def self.call(*args)
      new(*args).send(:call)
    end

    private

    # @param esa_client [Esa::Client]
    def initialize(esa_client:)
      @client = esa_client
    end

    # 実処理
    #
    # @return [Array<Hash>]
    def call
      posts = search_posts
      result = []

      posts.each do |post|
        full_name = post['full_name']
        body_md = post['body_md']

        # タイトルを見出し用に整形
        headline = full_name.match(/日報\/(.*) :sp:/)[1].gsub(/\)\//, ') ')
        # 作業日報の手前までが所感
        tmp = body_md.match(/(.*)## 本日の作業内容/m)[1]
        remarks = tmp.gsub(/Copied from: \[.*\]\(.*\)\r\n/, '').strip

        result << {
          headline: headline,
          remarks: remarks
        }
      end

      result
    end

    # 自分の今週の日報（月〜金, 最大 5 記事）を取得
    # 使うデータ（full_name, body_md) だけ返す
    #
    # @return [Array<Hash>] posts
    def search_posts
      response = client.posts(
        q: "@tmd45 in:\"日報\" created:>=#{last_monday}",
        sort: 'created', order: 'asc'
      )
      posts = response.body['posts']
      posts.map do |post|
        post.select { |k, _| ['full_name', 'body_md'].include?(k) }
      end
    end

    # @return [String] Exp. "2019-10-11"
    def last_monday
      today = Date.today
      last_monday = today - (today.wday - 1)
      last_monday.to_s
    end
  end
end

module HatenaBlog
  # NOTE: MonkeyPatch for atomutil
  class TextContent < Atom::Content
    def body=(value)
      @elem.add_text value
      self.type = 'text'
    end
  end

  class DraftMaker
    attr_reader :client, :contents

    def self.call(*args)
      new(*args).send(:call)
    end

    private

    # @param atompub_client [Atompub::Client]
    # @param contents [Array<Hash>]
    def initialize(atompub_client:, contents:)
      @client = atompub_client
      @contents = contents
    end

    # 実処理
    def call
      username = ENV['HATENA_USERNAME']
      blog_domain = ENV['HATENA_BLOG_DOMAIN']
      post_url = "https://blog.hatena.ne.jp/#{username}/#{blog_domain}/atom/entry"

      title = "[自動投稿][日記]所感週報 #{Date.today.to_s}"

      entry = Atom::Entry.new(
        title: title,
        content: body
      )
      app = Atom::Control.new(draft: 'yes')
      entry.add_control(app)

      pp client.create_entry(post_url, entry)
    end

    # はてなブログ投稿用に Markdown の本文を組み立てる
    #
    # @return [String]
    def body
      body = ['今週の所感です。']
      contents.each do |content|
        body << "### #{content[:headline]}"
        body << content[:remarks]
      end
      body.join("\r\n\r\n")
    end
  end
end

# esa
esa_client = Esa::Client.new(
  access_token: ENV['ESA_ACCESS_TOKEN'],
  current_team: ENV['ESA_CURRENT_TEAM']
)
contents = Esa::RemarksExporter.call(esa_client: esa_client)

# Hatena Blog
auth = Atompub::Auth::Wsse.new(
  username: ENV['HATENA_USERNAME'],
  password: ENV['HATENA_API_KEY']
)
atompub_client = Atompub::Client.new(auth: auth)
HatenaBlog::DraftMaker.call(atompub_client: atompub_client, contents: contents)
