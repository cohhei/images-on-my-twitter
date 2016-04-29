require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'omniauth'
require 'omniauth-twitter'
require 'twitter'
require 'twitter/profile'

class Array
  def twimg_urls
    if self.first.class == Twitter::Tweet then
      self.select { |tweet| tweet.media? }.
        map { |tweet| tweet.attrs[:entities][:media] }.
        flatten.
        map { |media| media[:media_url] }
    end
  end

  def instagram_urls
    if self.first.class == Twitter::Tweet then
      self.select { |tweet| tweet.attrs[:source].to_s.include? 'Instagram' }.
        map { |tweet| tweet.attrs[:entities][:urls].first[:expanded_url] + 'media?size=m' }
    end
  end
end

class SinatraApp < Sinatra::Base
  configure do
    set :sessions, true
  end

  helpers do
    def logged_in?
      session[:twitter_oauth]
    end

    def twitter
      Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['CONSUMER_KEY']
        config.consumer_secret     = ENV['CONSUMER_SECRET']
        config.access_token        = session[:twitter_oauth][:token]
        config.access_token_secret = session[:twitter_oauth][:secret]
      end
    end

    def photos_url
      max_id = twitter.user_timeline.first.id
      photos = []
      for n in 0..9 do
        timeline = twitter.user_timeline(
          max_id: max_id,
          count: 200,
          exclude_replies: true,
          include_rts: false)

        break if timeline.empty?

        photos += timeline.twimg_urls
        #photos += timeline.instagram_urls
        break if photos.count > 50

        max_id = timeline.last.id
      end
      photos
    end
  end

  use OmniAuth::Builder do
    provider :twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
  end

  get '/' do
    if logged_in? then
      @photos = session[:photos]
      #@photos.insert 4, session[:profile_image]
    end
    erb :index
  end

  get '/auth/failure' do
    redirect '/'
  end

  get '/auth/:provider/callback' do
    session[:twitter_oauth] = env['omniauth.auth'][:credentials]
    p "callback"
    p session[:twitter_oauth]
    profile_image_url = request.env['omniauth.auth']['info']['image']
    profile_image_url.slice!('_normal')
    session[:profile_image] = profile_image_url
    session[:photos] = photos_url
    redirect '/'
  end

  get '/logout' do
    session.clear
    redirect to('/')
  end
end

SinatraApp.run! if __FILE__ == $0
