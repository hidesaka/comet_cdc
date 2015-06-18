#!/usr/bin/env ruby

require 'json'
require 'pp'
require 'xml'
require 'time'
require 'fileutils'
require 'aws-sdk'
require 'open-uri'

$local_xml_dir="../xml"
$local_daily_dir="../daily"
$s3_xml_dir="xml/"
$s3_daily_dir="daily/"

ENV['TZ'] = 'Asia/Tokyo'

$num_wires = [
   396, 396, 396, 408, 408, 420, 420,
   432, 432, 444, 444, 456, 456, 468,
   468, 480, 480, 492, 492, 504, 504,
   516, 516, 528, 528, 540, 540, 552,
   552, 564, 564, 576, 576, 588, 588,
   600, 600, 612, 612
]

def obj2json(obj)
   JSON.generate(obj)
end

def get_total_wires
    $num_wires.reduce(0) { |memo, n| memo + n }
end

def get_last_date(now_utime_sec, num_wires, num_ave)
   remaining_wires = get_total_wires - num_wires
   string_speed = num_ave
   remaining_work_days = remaining_wires/string_speed
   #p string_speed
   #p remaining_work_days
   num_holidays = 0
   remaining_days=1
   current = Time.at(now_utime_sec)
   current_day = Date.new(current.year, current.mon, current.day)
   #puts "current_day #{current_day}"
   
   work_days=1
   while work_days < remaining_work_days do
      day = current_day + remaining_days
      #p day
      if (day.wday==0 or day.wday==6) then num_holidays+=1; remaining_days+=1; next; end
      if (day.mon==8 and day.day==13) then num_holidays+=1; remaining_days+=1; next; end
      if (day.mon==8 and day.day==14) then num_holidays+=1; remaining_days+=1; next; end
      remaining_days+=1
      work_days+=1
   end
   last_day = (current_day+remaining_days).strftime("%Y/%m/%d")
   last_utime_ms = (current_day+remaining_days).to_time.to_i * 1000 # ms
   #puts "num_holidays #{num_holidays}"
   #puts "remaining_days #{remaining_days}"
   #puts "last_day #{last_day}"
   [ last_day, last_utime_ms ]
end

def make_daily_data(xml_contents)
   doc = XML::Document.string(xml_contents)

   datum=[]
   (1..39).each do |layerid|
      doc.find("T_Data#{layerid}").each do |elem|
         dataID = elem.find("DataID")[0].content.to_i
         layerID = layerid
         wireID = elem.find("WireID")[0].content.to_i
         next unless (elem.find("Density1")[0])
         tBase = elem.find("TBase")[0].content
         density = elem.find("Density1")[0].content.to_f
         date = elem.find("Date1")[0].content
         freq = elem.find("Frq1")[0].content.to_f
         tens = elem.find("Ten1")[0].content.to_f
         data = {dataID: dataID, layerID: layerID, wireID: wireID, tBase: tBase, density: density, date: date, freq: freq, tens: tens}
         datum.push(data)
      end
   end

   datum
end

def make_stat(date, prev_stat, daily_data)
   p date
   days = (prev_stat.empty?)? 1: prev_stat[:days] + 1
   utime = Time.parse(date).to_i*1000 # (ms) for D3.js

   num_sum = daily_data.size
   num_sense = daily_data.count { |d| d[:tBase]=="50" }
   num_field = daily_data.count { |d| d[:tBase]=="80" }
   num_day = (prev_stat.empty?)? daily_data.size : daily_data.size - prev_stat[:num_sum]
   wire_tension_kg = daily_data.reduce(0) { |memo,d| memo + d[:tens]*0.001 }

   num_ave = daily_data.size/days
   num_bad = daily_data.count do |d|
      sense = (d[:tBase]=="50" && (d[:tens]<45.0 || d[:tens]>55.0) )
      field = (d[:tBase]=="80" && (d[:tens]<72.0 || d[:tens]>88.0) )
      sense || field
   end
   last_date, last_utime = get_last_date(utime/1000, num_sum, num_ave)
   stat =  {date: date, utime: utime, days: days, num_sum: num_sum, num_sense: num_sense, num_field: num_field, num_day: num_day, num_ave: num_ave, num_bad: num_bad,
      wire_tension_kg: wire_tension_kg, last_date: last_date, last_utime: last_utime}
   stat
end


##########
# Local  #
##########
def local_file_list(start_date, end_date)
   start_utime = Time.parse(start_date)
   end_utime   = Time.parse(end_date)
   
   prev_date = "none"
   Dir.glob("#{$local_xml_dir}/*/COMETCDC.xml") do |f|
      if (f =~ /(\d\d\d\d)(\d\d)(\d\d)\/+COMETCDC\.xml/)
         date_dir = "#{$1}#{$2}#{$3}"
         date = "#{$1}/#{$2}/#{$3}"
         utime = Time.parse(date)
         if (utime >= start_utime and utime <= end_utime)
            a =  {path: f, date: date, date_dir: date_dir, prev_date: prev_date}
            yield a
            prev_date = date
         end
      end
   end
end

def local_write_json(fname, obj)
   dir = File.dirname(fname)
   FileUtils.mkdir_p(dir)
   File.open("#{fname}","w") { |f| JSON.dump(obj, f) }
end

def local_read_json(fname)
   return [] if not File.exist?(fname)
   JSON.parse(File.open(fname).read, :symbolize_names => true)
end

def local_dump_json(fname)
   p local_read_json(fname)
end

def local_write_daily_datum(start_date, end_date)
   local_file_list(start_date, end_date) do |a|
      puts a
      #puts "path -> #{a[:path]}"
      #puts "date -> #{a[:date]}"
      #puts "date_dir -> #{a[:date_dir]}"
      data = make_daily_data(File.open(a[:path]).read)
      local_write_json("#{$local_daily_dir}/#{a[:date_dir]}/data.json", data)
   end
end

def local_write_daily_stats(start_date, end_date)
   local_file_list(start_date, end_date) do |a|
      puts a
      #puts "path -> #{a[:path]}"
      #puts "date -> #{a[:date]}"
      #puts "date_dir -> #{a[:date_dir]}"
      prev_stat = local_read_json("#{$local_daily_dir}/#{a[:date_dir]}/stat.json")
      daily_data = local_read_json("#{$local_daily_dir}/#{a[:date_dir]}/data.json")

      stat = make_stat(a[:date], prev_stat, daily_data)
      local_write_json("#{$local_daily_dir}/#{a[:date_dir]}/stat.json", stat)
   end
end

#########
#  S3   #
#########
def s3_file_list(start_date, end_date)
   start_utime = Time.parse(start_date)
   end_utime   = Time.parse(end_date)

   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   s3 = Aws::S3::Client.new

   prev_date = "none"
   s3.list_objects(bucket: "comet-cdc", prefix: $s3_xml_dir).contents.each do |obj|
      if (obj.key =~ /(\d\d\d\d)(\d\d)(\d\d)\/+COMETCDC\.xml/)
         date_dir = "#{$1}#{$2}#{$3}"
         date = "#{$1}/#{$2}/#{$3}"
         utime = Time.parse(date)
         s3_res = Aws::S3::Resource.new(region: 'ap-northeast-1')
         bucket = s3_res.bucket("comet-cdc")
         object = bucket.object(obj.key)
         url = object.presigned_url(:get)
         #puts "presigned_utr -> #{obj.presigned_url(:get, expires_in: 3600)}"
         if (utime >= start_utime and utime <= end_utime) 
            a =  {path: url, date: date, date_dir: date_dir, prev_date: prev_date}
            yield a
            prev_date = date
         end
      end
   end
end

def s3_write_json(key, obj)
   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   s3 = Aws::S3::Client.new
   key = key.gsub(/\/+/,'/')
   s3.put_object(bucket: "comet-cdc", body: obj2json(obj), key: key)
end

def s3_read_json(key)
   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   s3 = Aws::S3::Client.new
   key = key.gsub(/\/+/,'/')
   body = s3.get_object(bucket: "comet-cdc", key: key).body.read
   JSON.parse(body, :symbolize_names => true)
end

def s3_dump_json(key)
   p s3_read_json(key)
end

def s3_write_daily_datum(start_date, end_date)
   s3_file_list(start_date, end_date) do |a|
      puts a
      #puts "path -> #{a[:path]}"
      #puts "date -> #{a[:date]}"
      #puts "date_dir -> #{a[:date_dir]}"
      data = make_daily_data(open(a[:path]).read)
      s3_write_json("#{$s3_daily_dir}/#{a[:date_dir]}/data.json", data)
   end
end

def s3_write_daily_stats(start_date, end_date)
   s3_file_list(start_date, end_date) do |a|
      puts a
      #puts "path -> #{a[:path]}"
      #puts "date -> #{a[:date]}"
      #puts "date_dir -> #{a[:date_dir]}"
      prev_stat = s3_read_json("#{$s3_daily_dir}/#{a[:date_dir]}/stat.json")
      daily_data = s3_read_json("#{$s3_daily_dir}/#{a[:date_dir]}/data.json")

      stat = make_stat(a[:date], prev_stat, daily_data)
      s3_write_json("#{$s3_daily_dir}/#{a[:date_dir]}/stat.json", stat)
   end
end

USAGE=<<END
./script/test.rb <func_name> <arguments>
ex.

List of functions
END

if $0 == __FILE__
   if ARGV.size == 0
      puts USAGE
      exit
   end
   send(ARGV[0],*ARGV[1..-1])
end
