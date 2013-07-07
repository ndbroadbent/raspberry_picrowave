#!/usr/bin/env ruby
require 'sinatra'
require 'yaml'
require 'json'
require File.expand_path('../../microwave_daemon/lib/client', __FILE__)

configure do
  set :bind, '0.0.0.0'
  set :port, '80'

  set :microwave, Microwave::Daemon::Client.new
  set :barcodes_file, File.expand_path("../unknown_barcodes.yml", __FILE__)
end

def fetch_info
  begin
    settings.microwave.fetch_info
    @info = settings.microwave.info
    @info[:formatted_time] = (Time.mktime(@info[:time].to_i)).strftime("%-M:%S")
  rescue
    @info = nil
  end
end

get '/' do
  @barcodes = []
  if File.exists?(settings.barcodes_file)
    @barcodes = YAML.load_file(settings.barcodes_file)
  end

  fetch_info

  erb :touchpad
end

post '/clear_barcodes' do
  if File.exists?(settings.barcodes_file)
    File.delete(settings.barcodes_file)
  end
  redirect to('/')
end

get '/info.json' do
  @barcodes = []
  if File.exists?(settings.barcodes_file)
    @barcodes = YAML.load_file(settings.barcodes_file)
  end

  fetch_info
  @info ||= {error: true}

  content_type :json
  {info: @info, barcodes: @barcodes}.to_json
end

get '/button/:name' do
  puts params[:name]

end
