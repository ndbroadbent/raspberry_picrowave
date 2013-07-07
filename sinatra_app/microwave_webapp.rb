#!/usr/bin/env ruby
require 'sinatra'

get '/' do
  send_file File.expand_path('touchpad.html', settings.public_folder)
end

get '/button/:name' do
  puts params[:name]
end