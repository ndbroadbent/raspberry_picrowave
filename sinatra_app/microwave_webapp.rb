#!/usr/bin/env ruby
require 'sinatra'
require 'yaml'
require 'json'
require File.expand_path('../../microwave_daemon/lib/client', __FILE__)

configure do
  set :bind, '0.0.0.0'
  set :port, '80'

  connected = false
  while !connected
    begin
      set :microwave, Microwave::Daemon::Client.new
      connected = true
    rescue
      puts "Could not connect to microwave daemon... retrying after 1s"
      sleep 1
    end
  end

  set :barcodes_file, File.expand_path("../unknown_barcodes.yml", __FILE__)
end

def fetch_info
  begin
    settings.microwave.fetch_info
    @info = settings.microwave.info

    seconds = @info[:time].to_i % 60
    minutes = @info[:time].to_i / 60
    @info[:formatted_time] = format("%d:%02d", minutes, seconds)

    @info[:power_string] = case @info[:power]
    when 0
      "Off"
    when 3
      "Defrost"
    when 5
      "Low"
    when 7
      "Medium"
    when 10
      "High"
    else
      @info[:power]
    end
  rescue
    @info = nil
  end

  puts @info.inspect
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
  puts "Pressing button: #{params[:name]}"
  settings.microwave.send_request(:command => {new_button: params[:name]})
end
