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

configure :production do
   use Rack::Auth::Basic do |username, password|
      username == ENV['BASIC_AUTH_USERNAME'] && password == ENV['BASIC_AUTH_PASSWORD']
   end
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

get '/data.txt' do
   file = Tempfile.new("data.txt")
   data = s3_read_json("daily/current/data.json")
   data.each do |d|
      dataID = d[:dataID]
      layerID =d[:layerID]
      wireID = d[:wireID]
      tBase = d[:tBase]
      density =d[:density]
      date = d[:date]
      freq = d[:freq]
      tens = d[:tens]
      file.puts "#{date} #{layerID} #{wireID} #{tBase} #{density} #{freq} #{tens}"
   end
   file.close
   send_file(file.path, {filename: "data.txt"})
   file.unlink
end

get '/stats.txt' do
   file = Tempfile.new("stats.txt")
   stats = s3_read_json("stats/stats.json")
   if not stats.is_a? Array
      date = stats[:date]
      days =stats[:days]
      num_sum = stats[:num_sum]
      num_sense =stats[:num_sense]
      num_field = stats[:num_field]
      num_bad = stats[:num_bad]
      wire_tension_kg = stats[:wire_tension_kg].to_f
      str = sprintf "%s %s %s %s %s %s %5.2f\n", date, days, num_sum, num_sense, num_field, num_bad, wire_tension_kg
      file.puts str
   else
      stats.each do |d|
         date = d[:date]
         days =d[:days]
         num_sum = d[:num_sum]
         num_sense =d[:num_sense]
         num_field = d[:num_field]
         num_bad = d[:num_bad]
         wire_tension_kg = d[:wire_tension_kg].to_f
         str = sprintf "%s %s %s %s %s %s %5.2f\n", date, days, num_sum, num_sense, num_field, num_bad, wire_tension_kg
         file.puts str
      end
   end
   file.close
   send_file(file.path, {filename: "stats.txt"})
   file.unlink
end

def get_temp(in_or_out)
   file = Tempfile.new("temp_#{in_or_out}.txt")
   temps = s3_read_json("csv/#{in_or_out}.json")
   temps.each do |d|
      date = d[:date]
      temp =d[:temp]
      humid = d[:humid]
      file.puts "#{date} #{temp} #{humid}"
   end
   file.close
   send_file(file.path, {filename: "temp_#{in_or_out}.txt"})
   file.unlink
end

get '/temp_inside.txt' do 
   get_temp("inside")
end

get '/temp_outside.txt' do 
   get_temp("outside")
end

get '/dial_gauge.txt' do 
   file = Tempfile.new("dial_gauge.txt")
   body = s3_read_csv('csv/dial_gauge.csv') 
   msg=[]
   ary = body.split("\n")
   item = ary[1].split(",")
   date = item[0]
   time = item[1]
   deg10_1st =  (item[4].to_f + item[5].to_f)*1000
   deg90_1st =  (item[6].to_f + item[7].to_f)*1000
   deg180_1st = (item[8].to_f + item[9].to_f)*1000
   deg270_1st = (item[10].to_f+ item[11].to_f)*1000
   file.puts "#{date} #{time} 0 0 0 0"

   ary[2..-1].each do |line|
      item = line.split(",")
      date = item[0]
      time = item[1]
      deg10 =  (item[4].to_f + item[5].to_f)*1000
      deg90 =  (item[6].to_f + item[7].to_f)*1000
      deg180 = (item[8].to_f + item[9].to_f)*1000
      deg270 = (item[10].to_f+ item[11].to_f)*1000
      str = sprintf "%s %s %5.2f %5.2f %5.2f %5.2f\n", date, time, deg10-deg10_1st, deg90-deg90_1st, deg180-deg180_1st, deg270-deg270_1st
      file.puts str
   end
   file.close
   send_file(file.path, {filename: "dial_gauge.txt"})
   file.unlink
end

get '/tension_bar.txt' do 
   file = Tempfile.new("tension_bar.txt")
   body = s3_read_csv('csv/tension_bar.csv') 
   body.encode!("utf-8", :invalid=>:replace)
   body.gsub!("\r","\n")
   msg=[]
   ary = body.split("\n")
   ary[1..-1].each do |d|
      item = d.split(",")
      date = item[0]
      tens = item[1]
      next if date.nil? or date.empty?
      file.puts "#{date} #{tens}"
   end
   file.close
   send_file(file.path, {filename: "tension_bar.txt"})
   file.unlink
end
