#!/usr/bin/env ruby

require 'json'
require 'pp'
require 'xml'
require 'time'

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


def get_info(xml)
   doc = XML::Document.string(open(xml).read)

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

XML_DIR="public/xml/"
DAILY_DIR="public/daily/"
STAT_FILE="public/stats/stats.json"
   
def write_entry(date_str)
   Dir.mkdir("#{DAILY_DIR}/#{date_str}") unless File.exists?("#{DAILY_DIR}/#{date_str}")
   datum = get_info("#{XML_DIR}/#{date_str}/COMETCDC.xml")
   open("#{DAILY_DIR}/#{date_str}/data.json", "w") {|f| JSON.dump(datum, f)}
end

def read_in(date_str)
   str = open("#{DAILY_DIR}/#{date_str}/data.json", "r") {|f| f.read }
   JSON.parse(str, :symbolize_names => true)
end

def get_entries
   Dir.glob("#{XML_DIR}/20*") do |f|
      if (f=~/#{XML_DIR}\/(20.*)/)
         yield $1
      end
   end
end

def write_entries
   get_entries do |entry|
      puts entry
      write_entry(entry)
   end
end

def get_date(dir_name)
   # dir_name is 20150601 etc.
   # change -> 2015/06/01
   dir_name =~ /(....)(..)(..)/
   "#{$1}/#{$2}/#{$3}"
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


def get_stats
   stats=[]
   prev_size=0
   days=0
   get_entries do |entry|
      puts entry
      date = get_date(entry)
      utime = Time.parse(date).to_i*1000 # (ms) for D3.js
      datum = read_in(entry)
      days+=1
      num_sum = datum.size
      num_sense = datum.count { |data| data[:tBase]=="50" }
      num_field = datum.count { |data| data[:tBase]=="80" }
      num_day = datum.size-prev_size
      prev_size = datum.size
      wire_tension_kg = datum.reduce(0) { |memo,data| memo + data[:tens]*0.001 }

      num_ave = datum.size/days.to_f
      num_bad = datum.count do |data|
         sense = (data[:tBase]=="50" && (data[:tens]<45.0 || data[:tens]>55.0) )
         field = (data[:tBase]=="80" && (data[:tens]<72.0 || data[:tens]>88.0) )
         sense || field
      end
      last_date, last_utime = get_last_date(utime/1000, num_sum, num_ave)
      stat = {date: date, utime: utime, days: days, num_sum: num_sum, num_sense: num_sense, num_field: num_field, num_day: num_day, num_ave: num_ave, num_bad: num_bad,
      wire_tension_kg: wire_tension_kg, last_date: last_date, last_utime: last_utime}
      stats.push(stat)
   end
   stats
end

def write_stats
   stats = get_stats
   File.open(STAT_FILE,"w") { |f| JSON.dump(stats, f) }
end

p ARGV
if (ARGV[0]=="daily") then
   write_entry(ARGV[1])
elsif (ARGV[0]=="stats") then
   write_stats
end
#write_entry("20150610")
#write_entries
#write_stats
