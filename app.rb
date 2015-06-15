require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader'

require './script/test.rb'
require 'fileutils'

get '/' do 
   erb :index
end

post '/xml_upload' do 
   if params[:file]

      today=Time.now
      dir_name = sprintf("%d%02d%02d",today.year, today.month, today.day)

      save_path = "public/xml/#{dir_name}"
      FileUtils.mkdir(save_path) unless File.exists?(save_path)
      
      File.open("#{save_path}/#{params[:file][:filename]}", "w") do |f|
         f.write params[:file][:tempfile].read
      end

      # generate daily/dir_name/data.json
      write_entry(dir_name)

      # make link of current dir_name
      FileUtils.rm("public/daily/current") if File.exists?("public/daily/current")
      FileUtils.ln_s("#{dir_name}","public/daily/current")

      # generate stats/stats.json
      write_stats
      
      redirect '/'
   end
end

post '/csv_upload' do 
   if params[:file]
      File.open("public/csv/#{params[:file][:filename]}", "w") do |f|
         f.write params[:file][:tempfile].read
      end
      redirect '/'
   end
end
