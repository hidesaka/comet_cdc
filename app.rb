require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader'

require './script/test.rb'
require 'fileutils'

require 'aws-sdk'
require 'json'
require 'eventmachine'


#require 'logger'
#logdir = File.dirname(__FILE__)
#logger = Logger.new(logdir + "/log.txt")

configure :production do
   require 'newrelic_rpm'
end

use Rack::Auth::Basic do |username, password|
     username == ENV['BASIC_AUTH_USERNAME'] && password == ENV['BASIC_AUTH_PASSWORD']
end

get '/err/:message' do |msg|
   puts "/err/:message is called (msg = #{msg})"
   @err_msg = msg
   erb :err
end

get '/' do 
   erb :index
end

def merge_temp_data(body, location)
   # First three lines are header
   # "Date/Time","Date/Time","No.1","No.2"
   # "Date/Time","Date/Time","TR-72wf-FujiB4 Temperature","TR-72wf-FujiB4 Humidity"
   # "","","��C","%"
   
   #puts "==merge_temp_data=="
   #puts body
   #puts "==================="

   json_now = []

   i=0
   body.each_line do |line|
      i += 1
      next if (i<=3)
      puts line
      line.gsub!("\"","")
      #puts line
      items = line.split(",")
      date = items[0]
      utime = Time.parse(date).to_i*1000 # s -> ms
      temp = items[2].to_f
      humid = items[3].to_i
      #puts "date -> #{date}"
      #puts "utime -> #{utime}"
      #puts "temp -> #{temp}"
      #puts "humid -> #{humid}"
      hash = {date: date, utime: utime, temp: temp, humid: humid, location: location}
      json_now.push hash
   end

   json_prev = s3_read_json("csv/#{location}side.json")

   json_all = json_prev + json_now
   #puts "===json_all==="
   #puts json_all
   #puts "=============="

   json_all.sort_by! do |a|
      a[:utime]
   end

   json_all.uniq! do |a|
      a[:utime] 
   end

   json_all
end

post '/csv_upload' do 
   if params[:file]
      pid = fork do
         path = params[:file][:filename]

         basename = File.basename(path)
         body = params[:file][:tempfile].read

         if path.match(/(.*)side_(.*).csv/)
            s3_write_json("csv/#{$1}side.json", merge_temp_data(body,$1))
         end

         s3_write("csv/#{basename}", body)
         #return "success, file size was #{params[:file][:tempfile].size}"
      end
      Process.waitpid(pid)
      return "success, csv file is uploaded"

   else
      return "params[:file] is null"
   end
end


get '/xml_list' do 
   msg=[]
   s3_file_list("2015/05/26","2018/01/01") do |a|
      msg.push "#{a[:date]}<br/>"
   end
   msg.join()
end
