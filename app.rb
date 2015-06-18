require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader'

require './script/test.rb'
require 'fileutils'

require 'aws-sdk'
require 'json'

creds = JSON.load(File.read("secrets.json"))
Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
Aws.config[:region] = "ap-northeast-1"

def upload (body, key)
   s3 = Aws::S3::Client.new
   s3.put_object(bucket: "comet-cdc", body: body, key: key)
end

get '/' do 
   erb :index
end

post '/xml_upload' do 
   if params[:file]
      body = params[:file][:tempfile].read
      path = params[:file][:tempfile].path
      basename = File.basename(path)

      today=Time.now
      dir_name = sprintf("%d%02d%02d",today.year, today.month, today.day)

      #s3_upload(body, "xml/#{dir_name}/COMETCDC.xml")
      daily_data_json = xml_to_daily_data_with_json(body)
      #s3_upload(daily_data_json, "daily/#{dir_name}/data.json")

      s3_read_daily_datum("daily", "
      daily_stat_json = xml_to_daily_stat_with_json(body)
      
      s3_upload_stats # stats/stats.json

      redirect '/'
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
end


get '/xml_list' do 
   msg=[]
   get_entries do |date, datum|
      msg.push "date #{date}<br/>"
   end
   msg.join()
end
