require 'sinatra'
require 'sequel'
require 'json'
require 'haml'
require 'active_support'
gem 'rack-openid'
require 'rack/openid'

module Scripts
  def self.data
    @@data ||= make
  end
  
  def self.make
    db = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://cssget.db')
    make_table(db)
    db[:scripts]    
  end
  
  def self.make_table(db)
    db.create_table :scripts do
      primary_key :id
      String :name, :unique => true, :null => false
      String :version 
      String :src_url
      String :min_url
      String :author
      Text :description

      String :created_by
      Time :created_at
    end
  rescue Sequel::DatabaseError
    # assume table already exists
  end
end

class CssGet < Sinatra::Default
  VERSION = '0.1.1'


  # Session needs to be before Rack::OpenID
  use Rack::Session::Cookie
  use Rack::OpenID 
  
  enable :sessions

  get '/' do
    @scripts = Scripts.data.all
    haml :index
  end
  
  get '/login' do
    haml :login
  end

  post '/login' do
    if resp = request.env["rack.openid.response"]
      if resp.status == :success
        session[:openid] = resp.display_identifier
        #request_url = session[:request_url]
        #session[:request_url] = nil
        #redirect request_url || '/'
        redirect '/'
      else
        "Error: #{resp.status}"
      end
    else
      headers 'WWW-Authenticate' => Rack::OpenID.build_header(
        :identifier => params["openid_identifier"]
      )
      throw :halt, [401, 'got openid?']
    end
    
  end

  get '/scripts.json' do
    Scripts.data.all.to_json
  end
  
  before do

    if request.path_info.match(/new|edit/)
      unless session[:openid]
        session[:request_url] = request.path_info
        redirect '/login'
      end
    elsif !request.path_info.match(/delete/) and 
          request.path_info.match(/scripts/) and 
          request.request_method.match(/post/i)
      if session[:openid]
        @created_by = session[:openid]
      else
        redirect '/login'
      end
    end

  end

  get '/scripts/new' do
    haml :form
  end
  
  get '/scripts/:id/show' do
    throw :halt, [ 404, "No such script \"#{params[:id]}\"" ] unless @script = Scripts.data.filter(:name => params[:id]).first   
    haml :show, :locals => { :script => @script, :openid => session[:openid] }

  end

  get '/scripts/:id/edit' do
    throw :halt, [ 404, "No such script \"#{params[:id]}\"" ] unless @script = Scripts.data.filter(:name => params[:id]).first
    throw :halt, [ 404, "Only Creator able to alter script"] unless @script[:created_by] == session[:openid]
    haml :form, :locals => { :script => @script }

  end

  get '/scripts/:id' do
    throw :halt, [ 404, "No such script \"#{params[:id]}\"" ] unless Scripts.data.filter(:name => params[:id]).count > 0
    RestClient.post "http://stats.jackhq.com/graphs/#{params[:id]}", :value => 1, :api => "123456789"
    Scripts.data.filter(:name => params[:id]).first.to_json
  end
  
  post '/scripts' do
    Scripts.data << { 
        :name => params[:name], 
        :created_at => (params[:created_at] || Time.now), 
        :version => (params[:version] || ""), 
        :src_url => params[:src_url], 
        :min_url => (params[:min_url] || ""), 
        :author => params[:author], 
        :description => (params[:description] || ""),
        :created_by => session[:openid]
      }
    redirect '/'
  end
  
  post '/scripts/:id' do
    Scripts.data.filter(:name => params[:id], :created_by => session[:openid]).update( { 
        :version => (params[:version] || ""), 
        :src_url => params[:src_url], 
        :min_url => (params[:min_url] || ""), 
        :author => (params[:author] || ""), 
        :description => (params[:description] || "") 
    })
    redirect '/'    
  end

  post '/scripts/:id/delete' do
    #throw :halt, [ 404, "Only Creator able to remove script"] unless @script[:created_by] == params[:openid]
    Scripts.data.filter(:name => params[:id], :created_by => params[:openid]).delete
    #redirect '/'
    "ok"
  end
    
end
