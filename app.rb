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

      # xml
      upload(body, "xml/#{dir_name}/COMETCDC.xml")

      # generate daily/dir_name/data.json
      data = get_info(path)
      data_json = JSON.generate(data)
      upload(data_json, "daily/#{dir_name}/data.json")
      upload(data_json, "daily/current/data.json")

      # generate stats/stats.json
      stats = get_stats
      stats_json = JSON.generate(stats)
      upload(stats_json, "stats/stats.json")
      
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
