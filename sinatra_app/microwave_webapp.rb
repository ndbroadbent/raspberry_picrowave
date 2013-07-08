#!/usr/bin/env ruby
require 'sinatra'
require 'yaml'
require 'json'
require File.expand_path('../../microwave_daemon/lib/client', __FILE__)

configure do
  set server: 'thin', bind: '0.0.0.0', port: '80', connections: []

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

  set :barcodes_file, File.expand_path("../recent_barcodes.yml", __FILE__)
end

def fetch_info
  begin
    settings.microwave.fetch_info
    info = settings.microwave.info

    seconds = info[:time].to_i % 60
    minutes = info[:time].to_i / 60
    info[:formatted_time] = format("%d:%02d", minutes, seconds)

    info[:power_string] = case info[:power]
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
      info[:power]
    end
  rescue
    info = nil
  end

  return info
end

get '/' do
  if File.exists?(settings.barcodes_file)
    @barcodes = YAML.load_file(settings.barcodes_file)
  else
    @barcodes = {known: [], unknown: []}
  end

  @info = fetch_info

  erb :touchpad
end

post '/clear_barcodes' do
  if File.exists?(settings.barcodes_file)
    File.delete(settings.barcodes_file)
  end
  redirect to('/')
end

get '/events', provides: 'text/event-stream' do
  response.headers['X-Accel-Buffering'] = 'no' # Disable buffering for nginx
  stream :keep_open do |out|
    settings.connections << out
    out.callback { settings.connections.delete(out) }
  end
end

def format_event(body)
  "data: #{body}\n\n"
end

info_thread = Thread.new do
  previous_data = nil
  while true
    if settings.connections.any?
      if File.exists?(settings.barcodes_file)
        barcodes = YAML.load_file(settings.barcodes_file)
      else
        barcodes = {known: [], unknown: []}
      end
      info = fetch_info || {error: true}

      data = {info: info, barcodes: barcodes}

      if data != previous_data
        event = format_event(data.to_json)
        settings.connections.each { |out| out << event }

        previous_data = data
      end
    end

    sleep 0.2
  end
end

get '/button/:name' do
  puts "Pressing button: #{params[:name]}"
  settings.microwave.send_request(:command => {new_button: params[:name]})
end
