require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader'

require './script/test.rb'
require 'fileutils'

require 'aws-sdk'
require 'json'
require 'eventmachine'

def upload (body, key)
   s3 = Aws::S3::Client.new
   s3.put_object(bucket: "comet-cdc", body: body, key: key)
end

get '/err/:message' do |msg|
   puts "/err/:message is called (msg = #{msg})"
   @err_msg = msg
   erb :err
end

get '/' do 
   erb :index
end

post '/xml_upload' do 
   if params[:file]
      begin
         body = params[:file][:tempfile].read
         path = params[:file][:tempfile].path
         basename = File.basename(path)

         #today = Time.now
         today = Time.local(2015,6,19)
         dir_name = sprintf("%d%02d%02d",today.year, today.month, today.day)
         date = sprintf("%d/%02d/%02d",today.year, today.month, today.day)

         fork do
            s3_write("xml/#{dir_name}/COMETCDC.xml", body)
            s3_write_daily_datum(date, date) # daily/20150611/data.json
            s3_write_daily_stats(date, date) # daily/20150611/stat.json
            s3_write_stats(date) # stats/stats.json
            return "success, file size is #{params[:file][:tempfile].size}"
         end

      rescue => err
         return err.message
      end
   end
end

post '/csv_upload' do 
   if params[:file]
      path = params[:file][:filename]
      basename = File.basename(path)
      body = params[:file][:tempfile].read
      upload(body, "csv/#{basename}")
      redirect '/'
   end
   redirect '/err/no csv file'
end


get '/xml_list' do 
   msg=[]
   s3_file_list("2015/05/26","2018/01/01") do |a|
      msg.push "#{a[:date]}<br/>"
   end
   msg.join()
end
