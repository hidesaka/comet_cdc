#!/usr/bin/env ruby

require 'json'
require 'pp'
require 'xml'
require 'time'
require 'fileutils'
require 'aws-sdk'

$num_wires = [
   396, 396, 396, 408, 408, 420, 420,
   432, 432, 444, 444, 456, 456, 468,
   468, 480, 480, 492, 492, 504, 504,
   516, 516, 528, 528, 540, 540, 552,
   552, 564, 564, 576, 576, 588, 588,
   600, 600, 612, 612
]


def get_total_wires
    $num_wires.reduce(0) { |memo, n| memo + n }
end

def xml_to_day_info(xml_contents)
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


##########
# Local  #
##########

def local_xml_to_daily_datum(xml_dir)
   puts dir
   Dir.glob("#{xml_dir}/COMETCDC.xml") do |f|
      if (f =~ /(\d\d\d\d)(\d\d)(\d\d)\/+COMETCDC\.xml/)
         date = "#{$1}/#{$2}/#{$3}"
         puts "date -> #{date}"
         yield date, xml_to_day_info(open(f).read)
      end
   end
end

def local_xml_to_daily_stats(xml_dir, daily_dir)
   prev_size=0
   days=0
   local_xml_to_daily_datum(xml_dir) do |date, xml|
      days+=1
      puts date
      utime = Time.parse(date).to_i*1000 # (ms) for D3.js
      num_sum = xml.size
      num_sense = xml.count { |data| data[:tBase]=="50" }
      num_field = xml.count { |data| data[:tBase]=="80" }
      num_day = xml.size-prev_size
      prev_size = xml.size
      wire_tension_kg = xml.reduce(0) { |memo,data| memo + data[:tens]*0.001 }

      num_ave = xml.size/days.to_f
      num_bad = xml.count do |data|
         sense = (data[:tBase]=="50" && (data[:tens]<45.0 || data[:tens]>55.0) )
         field = (data[:tBase]=="80" && (data[:tens]<72.0 || data[:tens]>88.0) )
         sense || field
      end
      last_date, last_utime = get_last_date(utime/1000, num_sum, num_ave)
      stat = {date: date, utime: utime, days: days, num_sum: num_sum, num_sense: num_sense, num_field: num_field, num_day: num_day, num_ave: num_ave, num_bad: num_bad,
         wire_tension_kg: wire_tension_kg, last_date: last_date, last_utime: last_utime}
      yield date.gsub('/',''), stat
   end
end


#p ARGV
#if (ARGV[0]=="daily") then
#   write_entry(ARGV[1])
#elsif (ARGV[0]=="stats") then
#   write_stats
#end
#write_entry("20150610")
#write_entries

def local_write_daily_datum(xml_dir)
   local_xml_to_daily_datum(xml_dir) do |date, data|
      puts date
      date = date.gsub('/','')
      FileUtils.mkdir_p("../daily/#{date}")
      File.open("../daily/#{date}/data.json","w") { |f| JSON.dump(data, f) }
   end
end


def local_read_daily_datum(daily_dir)
   Dir.glob("#{daily_dir}/data.json") do |f|
      if (f =~ /(\d\d\d\d)(\d\d)(\d\d)\/+data\.json/)
         date = "#{$1}/#{$2}/#{$3}"
         data = JSON.parse(File.open(f).read, :symbolize_names => true)
         yield date.gsub('/',''), data
      end
   end
end

def local_dump_daily_datum(daily_dir)
   local_read_daily_datum(daily_dir) do |date, data|
      puts date
      puts data
   end
end


def local_write_daily_stats(xml_dir)
   local_xml_to_daily_stats(xml_dir, "../daily") do |date,stat|
      FileUtils.mkdir_p("../daily/#{date}")
      File.open("../daily/#{date}/stat.json","w") { |f| JSON.dump(stat, f) }
   end
end

def local_read_daily_stats(daily_dir)
   Dir.glob("#{daily_dir}/stat.json") do |f|
      if (f =~ /(\d\d\d\d)(\d\d)(\d\d)\/+stat\.json/)
         date = "#{$1}/#{$2}/#{$3}"
         stat = JSON.parse(File.open(f).read, :symbolize_names => true)
         yield date.gsub('/',''), stat
      end
   end
end

def local_dump_daily_stats(daily_dir)
   local_read_daily_stats(daily_dir) do |date, stat|
      puts date
      puts stat
   end
end


#############
#  S3       #
#############

def s3_xml_to_daily_datum(xml_dir='')
   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   bucket="comet-cdc"
   s3 = Aws::S3::Client.new
   s3.list_objects(bucket: bucket, prefix: "xml/").contents.each do |obj|
      if (obj.key =~ /(\d\d\d\d)(\d\d)(\d\d)\/+COMETCDC\.xml/)
         date = "#{$1}/#{$2}/#{$3}"
         if (xml_dir.empty? or xml_dir === "#{$1}#{$2}#{$3}") 
            yield date, xml_to_day_info(s3.get_object(bucket: bucket, key: obj.key).body.read)
         end
      end
   end
end

def s3_xml_to_daily_stats(xml_dir='')
   prev_size=0
   days=0
   s3_xml_to_daily_datum(xml_dir) do |date, xml|
      days+=1
      puts date
      utime = Time.parse(date).to_i*1000 # (ms) for D3.js
      num_sum = xml.size
      num_sense = xml.count { |data| data[:tBase]=="50" }
      num_field = xml.count { |data| data[:tBase]=="80" }
      num_day = xml.size-prev_size
      prev_size = xml.size
      wire_tension_kg = xml.reduce(0) { |memo,data| memo + data[:tens]*0.001 }

      num_ave = xml.size/days.to_f
      num_bad = xml.count do |data|
         sense = (data[:tBase]=="50" && (data[:tens]<45.0 || data[:tens]>55.0) )
         field = (data[:tBase]=="80" && (data[:tens]<72.0 || data[:tens]>88.0) )
         sense || field
      end
      last_date, last_utime = get_last_date(utime/1000, num_sum, num_ave)
      stat = {date: date, utime: utime, days: days, num_sum: num_sum, num_sense: num_sense, num_field: num_field, num_day: num_day, num_ave: num_ave, num_bad: num_bad,
         wire_tension_kg: wire_tension_kg, last_date: last_date, last_utime: last_utime}
      yield date.gsub('/',''), stat
   end
end

def s3_upload(body, key)
   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   s3 = Aws::S3::Client.new
   s3.put_object(bucket: "comet-cdc", body: body, key: key)
end

def s3_write_daily_datum(xml_dir='')
   s3_xml_to_daily_datum(xml_dir) do |date, data|
      puts date
      date = date.gsub('/','')
      s3_upload(JSON.generate(data), "daily/#{date}/data.json")
   end
end

def s3_read_daily_datum(daily_dir='')
   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   bucket="comet-cdc"
   s3 = Aws::S3::Client.new
   s3.list_objects(bucket: bucket, prefix: "daily/").contents.each do |obj|
      #puts "obj.key -> #{obj.key}"
      if (obj.key =~ /(\d\d\d\d)(\d\d)(\d\d)\/+data\.json/)
         date = "#{$1}/#{$2}/#{$3}"
         if (daily_dir.empty? or daily_dir === "#{$1}#{$2}#{$3}") 
            body = s3.get_object(bucket: bucket, key: obj.key).body.read
            data = JSON.parse(body, :symbolize_names => true)
            yield date.gsub('/',''), data
         end
      end
   end
end

def s3_dump_daily_datum(daily_dir='')
   s3_read_daily_datum(daily_dir) do |date, data|
      puts date
      puts data
   end
end

def s3_write_daily_stats(xml_dir='')
   s3_xml_to_daily_stats(xml_dir) do |date,stat|
      puts date
      puts stat
      s3_upload(JSON.generate(stat), "daily/#{date}/stat.json")
   end
end

def s3_read_daily_stats(daily_dir='')
   creds = JSON.load(File.read("secrets.json"))
   Aws.config[:credentials] = Aws::Credentials.new(creds["AccessKeyId"], creds["SecretAccessKey"])
   Aws.config[:region] = "ap-northeast-1"
   bucket="comet-cdc"
   s3 = Aws::S3::Client.new
   s3.list_objects(bucket: bucket, prefix: "daily/").contents.each do |obj|
      if (obj.key =~ /(\d\d\d\d)(\d\d)(\d\d)\/+stat\.json/)
         date = "#{$1}/#{$2}/#{$3}"
         #puts "date -> #{date}"
         if (daily_dir.empty? or daily_dir === "#{$1}#{$2}#{$3}") 
            body = s3.get_object(bucket: bucket, key: obj.key).body.read
            stat = JSON.parse(body, :symbolize_names => true)
            yield date.gsub('/',''), stat
         end
      end
   end
end

def s3_dump_daily_stats(daily_dir='')
   s3_read_daily_stats(daily_dir) do |date, stat|
      puts date
      puts stat
   end
end

###########
# uplload xml/data/stat/stats
###########
def upload_xml(xml_body, dir_name)
   s3_upload(xml_body, "xml/#{dir_name}/COMETCDC.xml")
end

def upload_data(xml_body, dir_name)
   data = xml_to_day_info(xml_body)
   data_json = JSON.generate(data)
   s3_upload(data_json, "daily/#{dir_name}/data.json")
   s3_upload(data_json, "daily/current/data.json")
end

def local_upload_daily_datum(daily_dir)
   local_read_daily_datum(daily_dir) do |date, stat| 
      puts date
      s3_upload(JSON.generate(stat), "daily/#{date}/data.json")
   end
end

def local_upload_daily_stat(daily_dir)
   local_read_daily_stats(daily_dir) do |date, stat| 
      puts date
      s3_upload(JSON.generate(stat), "daily/#{date}/stat.json")
   end
end

def s3_upload_stats
   stats = []
   s3_read_daily_stats('') { |date, stat| stats.push stat }
   s3_upload(JSON.generate(stats), "stats/stats.json")
end

def local_upload_stats
   stats = []
   local_read_daily_stats("../daily/*/") { |date, stat| stats.push stat }
   puts stats
   s3_upload(JSON.generate(stats), "stats/stats.json")
end

USAGE=<<END
./script/test.rb <func_name> <arguments>
ex.
./script/test.rb local_write_daily_datum("../daily/*/")

List of functions
   def local_write_daily_datum(xml_dir)
   def local_read_daily_datum(daily_dir)
   def local_dump_daily_datum(daily_dir)
   def local_write_daily_stats(xml_dir)
   def local_read_daily_stats(daily_dir)
   def local_dump_daily_stats(daily_dir)
   def s3_write_daily_datum(xml_dir='')
   def s3_read_daily_datum(daily_dir='')
   def s3_dump_daily_datum(daily_dir='')
   def s3_write_daily_stats(xml_dir='')
   def s3_read_daily_stats(daily_dir='')
   def s3_dump_daily_stats(daily_dir='')
   def local_upload_daily_datum(daily_dir)
   def local_upload_daily_stat(daily_dir)
   def s3_upload_stats
   def local_upload_stats
END

if $0 == __FILE__
   if ARGV.size == 0
      puts USAGE
      exit
   end
   send(ARGV[0],ARGV[1])
end
