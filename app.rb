require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader'

require './script/test.rb'
require 'fileutils'

require 'aws-sdk'

creds = JSON.load(File.read("secrets.json"))
Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
Aws.config[:region] = "ap-northeast-1"

def upload (body, dst_fname)
#   file_open = File.open(src_fname)
   s3 = Aws::S3::Client.new
   #resp = s3.list_buckets
   #puts resp.buckets.map(&:name)
   s3.put_object(
      bucket: "comet-cdc",
      body: body,
      key: dst_fname
   )
end

get '/' do 
   erb :index
end

post '/xml_upload' do 
   if params[:file]

      today=Time.now
      dir_name = sprintf("%d%02d%02d",today.year, today.month, today.day)

      #save_path = "public/xml/#{dir_name}"
      #FileUtils.mkdir(save_path) unless File.exists?(save_path)
      
      #File.open("#{save_path}/#{params[:file][:filename]}", "w") do |f|
      #   f.write params[:file][:tempfile].read
      #end
      
      #upload(params[:file][:tempfile].read, "xml/#{dir_name}/COMETCDC.xml")

      # generate daily/dir_name/data.json
      #write_entry(dir_name)
      data_json = get_info(params[:file][:filename])
      #upload("this is test", "daily/#{dir_name}/data.json")
      upload(data_json, "daily/#{dir_name}/data.json")
      #upload(data_json, "daily/current/data.json")

      # make link of current dir_name
      #FileUtils.rm("public/daily/current") if File.exists?("public/daily/current")
      #FileUtils.ln_s("#{dir_name}","public/daily/current")

      # generate stats/stats.json
      #stats_json = get_stats
      #upload(stats_json, "stats/stats.json")
      
      redirect '/'
   end
end

post '/csv_upload' do 
   if params[:file]
      #File.open("public/csv/#{params[:file][:filename]}", "w") do |f|
      #   f.write params[:file][:tempfile].read
      #end
      upload(params[:file][:tempfile], "csv/#{params[:file][:filename]}")
      redirect '/'
   end
end
