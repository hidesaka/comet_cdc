#!/usr/bin/env ruby

require 'json'
require 'pp'
require 'xml'
require 'time'

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

   all_wires = datum.reduce(Hash.new(0)) do |hash, data|
      hash[data[:layerID]]+=1
      hash
   end

   bad_wires = datum.reduce(Hash.new(0)) do |hash, data|
      hash[data[:layerID]]+=1 if (data[:tBase]=="50" and (data[:tens] <45.0 or data[:tens] >55.0))
      hash[data[:layerID]]+=1 if (data[:tBase]=="80" and (data[:tens] <72.0 or data[:tens] >88.0))
      hash
   end

   [all_wires, bad_wires]
end

XML_DIR="../xml/"
DAILY_DIR="../daily/"
def write_out(date_str)
   Dir.mkdir("#{DAILY_DIR}/#{date_str}") unless File.exists?("#{DAILY_DIR}/#{date_str}")
   all_wires, bad_wires = get_info("#{XML_DIR}/#{date_str}/COMETCDC.xml")
   open("#{DAILY_DIR}/#{date_str}/all_wires.json", "w") {|f| JSON.dump(all_wires, f)}
   open("#{DAILY_DIR}/#{date_str}/bad_wires.json", "w") {|f| JSON.dump(bad_wires, f)}
end

def read_in(date_str)
   all_wires = open("#{DAILY_DIR}/#{date_str}/all_wires.json", "r") {|f| JSON.load(f)}
   bad_wires = open("#{DAILY_DIR}/#{date_str}/bad_wires.json", "r") {|f| JSON.load(f)}
   [all_wires, bad_wires]
end

def get_entry
   Dir.glob("#{XML_DIR}/20*") do |f|
      if (f=~/#{XML_DIR}\/(20.*)/)
         yield $1
      end
   end
end

def write_all
   get_entry do |entry|
      write_out(entry)
   end
end

def sum_up
   all_wires=[]
   all_wires_in_day=[]
   ave_wires=[]
   bad_wires=[]
   wire_map=[] # list of [layerid, wireid, tension]
   get_entry do |entry|
      puts entry
      all_wire, bad_wire = read_in(entry)
      n1 = all_wire.values.reduce(0) {|memo,n| memo+n }
      n2 = bad_wire.values.reduce(0) {|memo,n| memo+n }
      #p n1
      all_wires.push(n1)
      all_wires.each_with_index do |n, i|
         all_wires_in_day[i] = (i==0)?all_wires[i]: all_wires[i] - all_wires[i-1]
         ave_wires[i] = all_wires[i]/(i+1).to_f
      end
      bad_wires.push(n2)
   end
   p all_wires
   p all_wires_in_day
   p ave_wires
   p bad_wires
   p wire_map
   #pp bad_wires
   #num_wires_over = all_wires.each_with_index.map {|e,i| p all_wires[0..i] }
   #num_wires_per_day = all_wires.each_with_index.map {|e,i| p all_wires[0..i] }
end

write_all
#sum_up
#write_out("20150609")
