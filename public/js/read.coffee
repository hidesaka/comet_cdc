###############
# Global vars #
###############
spin_opts = {
  lines: 13 # The number of lines to draw
  length: 28 # The length of each line
  width: 14 # The line thickness
  radius: 42 # The radius of the inner circle
  scale: 1 # Scales overall size of the spinner
  corners: 1 # Corner roundness (0..1)
  color: '#000' # #rgb or #rrggbb or array of colors
  opacity: 0.25 # Opacity of the lines
  rotate: 0 # The rotation offset
  direction: 1 # 1: clockwise, -1: counterclockwise
  speed: 1 # Rounds per second
  trail: 60 # Afterglow percentage
  fps: 20 # Frames per second when using setTimeout() as a fallback for CSS
  zIndex: 2e9 # The z-index (defaults to 2000000000)
  className: 'spinner' # The CSS class to assign to the spinner
  top: '60%' # Top position relative to parent
  left: '40%' # Left position relative to parent
  shadow: false # Whether to render a shadow
  hwaccel: false # Whether to use hardware acceleration
  position: 'absolute' # Element positioning
}

#
diam = 180
w = 650
h = 650

margin = {top: 20, right: 150, bottom: 50, left: 80}
width = w - margin.left - margin.right
height = 300 - margin.top - margin.bottom

numWires = [ 
  396, 396, 396, 408, 408, 420, 420,
   432, 432, 444, 444, 456, 456, 468, 
   468, 480, 480, 492, 492, 504, 504, 
   516, 516, 528, 528, 540, 540, 552, 
   552, 564, 564, 576, 576, 588, 588, 
   600, 600, 612, 612
]

numTotalWires = _.reduce(numWires, (memo, num) -> memo+num)

get_xypos = (layerid, wireid, num_wires) ->
  r = 50+(layerid-1)
  deg = (wireid-1)/num_wires*360
  rad = deg/180.0*Math.PI
  x = r*Math.cos(rad)
  y = r*Math.sin(rad)
  {x: x, y: y}

holes = []
for num,i in numWires
  for j in [0..num]
    holes.push(get_xypos(i+1, j+1, numWires[i]))

#############
# Functions #
#############
#get_today_name = (xmlDoc) ->
#  console.log xmlDoc
#  return
#  #today = new Date;
#  year = today.getFullYear()
#  month = today.getMonth()+1
#  date = today.getDate()
#  month2 = ("00"+month).substr(-2)
#  date2  = ("00"+date).substr(-2)
#  format_date = "#{year}/#{month2}/#{date2}"
#  dirname = format_date.replace(/\//g, '')
#  [format_date, dirname]


get_last_date = (now_utime_sec, num_wires, num_ave) ->
  remaining_wires = numTotalWires - num_wires
  string_speed = num_ave
  remaining_work_days = remaining_wires/string_speed
  #p string_speed
  #p remaining_work_days
  num_holidays = 0
  remaining_days = 1
  #current = new Date(now_utime_sec*1000)
  #current_day = Date.new(current.year, current.mon, current.day)
  #puts "current_day #{current_day}"
  
  work_days = 1
  loop
    break if work_days >= remaining_work_days
    #day = current_day + remaining_days
    day = new Date((now_utime_sec + remaining_days*24*60*60)*1000) # ms
    #p day
    if (day.getDay()==0 or day.getDay()==6)          then num_holidays+=1; remaining_days+=1; continue;
    if ((day.getMonth()+1)==8 and day.getDate()==13) then num_holidays+=1; remaining_days+=1; continue;
    if ((day.getMonth()+1)==8 and day.getDate()==14) then num_holidays+=1; remaining_days+=1; continue;
    remaining_days+=1
    work_days+=1

  last_utime_ms = (now_utime_sec + remaining_days*24*60*60)*1000
  last_date = new Date(last_utime_ms)
  last_day = "#{last_date.getFullYear()}/#{last_date.getMonth()+1}/#{last_date.getDate()}"
  #console.log("remaining_days #{remaining_days}")
  #console.log("last_day #{last_day}")
  [ last_day, last_utime_ms ]


make_daily_data = (xml) ->
  today_date=""
  today_dir=""
  latest_date=0
  datum=[]
  for layerid in [1..39]
    layerID = layerid
    layer = xml.getElementsByTagName("T_Data#{layerid}")
    for wire,i in layer
      dataID = wire.getElementsByTagName("DataID")[0].childNodes[0].nodeValue
      wireID = parseInt(wire.getElementsByTagName("WireID")[0].childNodes[0].nodeValue)
      continue if not wire.getElementsByTagName("Density1")[0]
      density = wire.getElementsByTagName("Density1")[0].childNodes[0].nodeValue
      tBase = wire.getElementsByTagName("TBase")[0].childNodes[0].nodeValue
      date = wire.getElementsByTagName("Date1")[0].childNodes[0].nodeValue
      freq = wire.getElementsByTagName("Frq1")[0].childNodes[0].nodeValue
      tens = wire.getElementsByTagName("Ten1")[0].childNodes[0].nodeValue
      data = {dataID: dataID, layerID: layerID, wireID: wireID, tBase: tBase, density: density, date: date, freq: freq, tens: tens}

      datum.push(data)
      date_as_int = parseInt(date.replace(/\//g, ''))
      if date_as_int > latest_date
        latest_date = date_as_int
        today_date = date
        today_dir = date_as_int
  
  [today_date, today_dir, datum]

make_stat = (today_date, prev_stat, daily_data) ->
   days = if not prev_stat? then 1 else prev_stat.days + 1
   #console.log("make_stat: days #{days}")
   utime = new Date("#{today_date} 00:00:00").getTime() # (ms) for D3.js

   num_sum = daily_data.length
   num_sense = _.filter(daily_data, (d) -> d.tBase=="50").length
   num_field = _.filter(daily_data, (d) -> d.tBase=="80").length
   num_day = if not prev_stat? then daily_data.length else daily_data.length - prev_stat.num_sum
   wire_tension_kg = _.reduce(daily_data, ((memo, d) -> memo + d.tens*0.001), 0)

   num_ave = parseInt(daily_data.length/days)
   num_bad = 0 
   for d in daily_data
     num_bad++ if d.tBase=="50" and (d.tens<45.0 or d.tens>55.0)
     num_bad++ if d.tBase=="80" and (d.tens<72.0 or d.tens>88.0)
   [last_date, last_utime] = get_last_date(utime/1000, num_sum, num_ave)
   stat =  {date: today_date, utime: utime, days: days, num_sum: num_sum, num_sense: num_sense, num_field: num_field, num_day: num_day, num_ave: num_ave, num_bad: num_bad, wire_tension_kg: wire_tension_kg, last_date: last_date, last_utime: last_utime}
   #console.log("make_stat:")
   #console.log(stat)
   stat

append_svg = (id) ->
  d3.select(id).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(#{margin.left}, #{margin.top})")

make_frame = (svg, xtitle, ytitle, xdomain, ydomain, options) ->
  svg.selectAll("g").remove()

  xScale=""
  if options.xaxis_type=="roundBands"
    #console.log("select xaxis roundBands")
    xScale = d3.scale.ordinal().domain(xdomain).rangeRoundBands([0, width])
  else if options.xaxis_type=="time"
    #console.log("select xaxis time")
    xScale = d3.time.scale().domain(xdomain).range([0, width]).nice()
  else
    #console.log("select xaxis linear")
    xScale = d3.scale.linear().domain(xdomain).range([0, width])
 
  yScale = d3.scale.linear().domain(ydomain).range([height, 0]).nice()

  if not options.no_axis
    tick_label_dx = 0
    tick_label_dy = 10
    tick_label_rotate = "0"
    xAxis = d3.svg.axis().scale(xScale).orient("bottom")

    if options.xaxis_tickValues?
      #console.log(options.xaxis_tickValues);
      xAxis.tickValues(options.xaxis_tickValues)

    if options.xaxis_type=="time"
      xAxis.ticks(5).tickFormat(d3.time.format('%b %d'))
      tick_label_rotate = "-65"
      tick_label_dx = -30
      tick_label_dy = -1

    yAxis = d3.svg.axis().scale(yScale).orient("left")

    xx = svg.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(0," + height + ")")
            .call(xAxis)

    xx.selectAll("text")
      .attr("transform", "rotate("+tick_label_rotate+")")
      .attr("text-anchor", "start")
      .attr("dx", tick_label_dx)
      .attr("dy", tick_label_dy)

    xx.append("text")
            .attr("x", width+8)
            .attr("y", 10)
            .attr("text-anchor", "start")
            .text(xtitle)

  svg.append("g")
     .attr("class", "axis")
     .call(yAxis)
     .append("text")
     .attr("transform", "rotate(-90)")
     .attr("y", -55)
     .attr("dy", ".71em")
     .style("text-anchor", "end")
     .text(ytitle)

  { "svg": svg, "xScale": xScale, "yScale": yScale }


makeBarChart = (frame, data, xdata, ydata, fillColor, tooltip) ->
  frame.svg.selectAll("rect").remove()
  frame.svg.selectAll(".bar")
       .data(data)
       .enter().append("rect")
       .attr("fill",fillColor)
       .attr("x", (d) -> frame.xScale(d[xdata]))
       .attr("width", frame.xScale.rangeBand()*0.97)
       #.attr("width", frame.xScale.rangeBand() - 5)
       .attr("y", height)
       .attr("height", 0)
       .transition()
       .duration(1000)
       .attr("y", (d, i) -> frame.yScale(d[ydata]))
       .attr("height", (d) -> height - frame.yScale(d[ydata]))

  makeTooltip(frame, "rect", data, xdata, ydata, tooltip.label) if (tooltip)


makeScatterPlot = (frame, data, xdata, ydata, options, legend_entry, tooltip) ->
  if options.line_stroke
    line = d3.svg.line()
          .x((d)-> frame.xScale(d[xdata]))
          .y((d)-> frame.yScale(d[ydata]))
    frame.svg.append("path")
         .attr("stroke", options.line_stroke)
         .attr("fill", "none")
         .attr("d", line(data))

  frame.svg.selectAll("circle").remove()

  if legend_entry.length!=0
    #add legend   
    legend = frame.svg.append("g")
              .attr("x", width - 65)
              .attr("y", 25)
              .attr("height", 100)
              .attr("width", 100)
              .selectAll("text")
              .data(legend_entry)
              .enter()
              .append("text")
              .attr("x", w-180)
              .attr("y", (d)-> d.ypos)
              .attr("height",30)
              .attr("width",100)
              .style("fill", (d) -> d.stroke)
              .text((d) -> d.label)

    frame.svg.append("g")
         .attr("x", width - 75)
         .attr("y", 25)
         .attr("height", 100)
         .attr("width", 100)
         .selectAll(".circle")
         .data(legend_entry)
         .enter()
         .append("circle")
         .attr("cx", w-190)
         .attr("cy", (d)-> d.ypos - 4)
         .attr("r", 3)
         .attr("fill", (d)-> d.fill)
         .attr("stroke",(d)-> d.stroke)
         .attr("stroke-width", "1px")

  frame.svg.selectAll(".circle")
       .data(data)
       .enter()
       .append("g")
       .attr("class","dot") # Need to distinguish from circle for legend
       .append("circle")
       .attr("cx", (d,i)-> frame.xScale(d[xdata]))
       .attr("cy", (d,i)-> frame.yScale(d[ydata]))
       .attr("r",  options.r)
       .attr("fill", options.fill)
       .attr("stroke",options.stroke)
       .attr("stroke-width", options.stroke_width)

  makeTooltip(frame, ".dot circle", data, xdata, ydata, tooltip.label) if (tooltip) 


makeLine = (frame, class_name, points) -> 
  line = d3.svg.line().x((d) -> frame.xScale(d.x)).y((d) ->frame.yScale(d.y))
  frame.svg.append("path").datum(points).attr("class", class_name).attr("d", line)


makeStatBox = (frame, x, y, text) -> 
  frame.svg.select("text").remove()
  frame.svg.append("text")
       .attr("x", x)
       .attr("y", y)
       .text(text)

makeTooltip = (frame, class_name, data, xdata, ydata, labels) -> 
  focus = frame.svg.append("g").attr("class","focus").style("display","none")
  focus.append("rect").attr("opacity","0.6").attr("x",9).attr("y",9).attr("rx",2).attr("ry",2).attr("width",30)
        .attr("height", -> if labels.length==1 then return 20 else return labels.length*17)

  focus.selectAll("text").data(labels).enter().append("text")
       .attr("x", 14)
       .attr("y", 12)
       .attr("font-family", "Inconsolata")
       .attr("font-size", "10px")
       .attr("fill", "white");

  get_msg = (d, label, i) -> 
    msg = label.prefix || ''
    for ent,i in label.data
      if typeof(ent)=='function' then msg += ent(d) else msg += d[ent]
      msg += label.separator || '' if (i<label.data.length-1) 
    msg += label.postfix || ''

  frame.svg.selectAll(class_name)
       .data(data)
       .on "mouseover", -> focus.style("display", null)
       .on "mouseout" , -> focus.style("display", "none") 
       .on "mousemove", (d) -> 
           xval = if (typeof(xdata)=='function') then xdata(d) else d[xdata]
           yval = if (typeof(ydata)=='function') then ydata(d) else d[ydata]
           focus.select("rect").attr("transform", "translate(" + frame.xScale(xval) + "," + (frame.yScale(yval)-10) + ")")
           focus.select("rect").attr("width", ->
             line = []
             focus.selectAll("text").each (label, i) -> line.push(get_msg(d, label, i))
             max_len = d3.max(line, (d) -> d.length)
             #console.log(line)
             14+max_len*4.7)

           focus.selectAll("text").attr("transform", (_,i) -> "translate(#{frame.xScale(xval)}, #{frame.yScale(yval)+i*15})")
           focus.selectAll("text").text (label,i) -> get_msg(d, label, i)

class S3
  constructor: ->
    @awsRegion = "us-east-1"
    @cognitoParams = IdentityPoolId: "us-east-1:435dfdc9-d483-4f5e-8f8b-27e3569ad9af"
    @s3BucketName = "comet-cdc"
    @s3RegionName = "ap-northeast-1"
    AWS.config.region = @awsRegion
    AWS.config.credentials = new AWS.CognitoIdentityCredentials(@cognitoParams)
    AWS.config.credentials.get (err) -> console.log "Cognito Identity Id: " + AWS.config.credentials.identityId if (!err) 
    @s3 = new AWS.S3 {params: {Bucket: @s3BucketName, Region: @s3RegionName}}
    console.log("=== s3 ====");
    console.log(@s3);
    console.log("===========");


  getObject: (name, callback) ->
    @s3.listObjects (err, data) =>
      for obj in data.Contents when obj.Key==name
        callback @s3.getSignedUrl('getObject', {Bucket: @s3BucketName, Key: obj.Key})
   
  putObject: (name, body, callback_upload, callback_progress) ->
    params = {Key: name, Body: body}
    upload = @s3.upload(params, (err, data) -> callback_upload(err, data))
    upload.on('httpUploadProgress', (event) -> callback_progress(event))
  
  putObjectWithProgress: (name, body, div_file, div_msg, div_bar) ->
    # initialization
    $(div_msg).show()
    $(div_bar).attr("value", 0)
    $(div_bar).show()
    $(div_file).attr("disabled","disabled")

    @putObject name, body
      , (err, data) -> 
        if (err)
          console.log("there is error on s3.putObject #{err}")
        else
          console.log("succeed to upload #{name}")
          $(div_file).val("").removeAttr("disabled")
          $(div_msg).html("done!").fadeOut(3000)
          $(div_bar).fadeOut(3000)
      , (event) ->
        progre = parseInt(event.loaded/event.total*10000)/100
        #console.log(progre+"%") 
        $(div_msg).height("30px")
        $(div_msg).html("Uploading.. " + progre+"%")
        $(div_bar).attr("value", progre)

  getJSON_prev_stat: (today, callback) ->
    today_as_int = parseInt(today)
    latest_date = ""
    @s3.listObjects (err, data) =>
      for obj in data.Contents
        a = obj.Key.match(/daily\/(\d\d\d\d\d\d\d\d)\/stat.json/)
        continue if not a
        #console.log "match -> a[0] #{a[0]} a[1] #{a[1]}"
        date_as_int = parseInt(a[1])
        latest_date = a[1] if date_as_int < today_as_int

      #console.log("latest_date #{latest_date}")
      #console.log("today #{today}")
       
      # check 
      @getObject "daily/#{latest_date}/stat.json", (url) ->
        d3.json(url, (data) -> callback(data))
         
  getJSON_stats: (callback) ->
    @s3.listObjects (err, data) =>
      for obj in data.Contents when obj.Key=="stats/stats.json"
        @getObject obj.Key, (url) ->
          d3.json(url, (data) -> callback(data))
         
         

class DialGauge
  @read_csv: (csv) ->
    j=0
    data=[]
    for ent in csv
      v11 = ent["10deg_1mm"]
      v12 = ent["10deg_10um"]
      v21 = ent["90deg_1mm"]
      v22 = ent["90deg_10um"]
      v31 = ent["180deg_1mm"]
      v32 = ent["180deg_10um"]
      v41 = ent["270deg_1mm"]
      v42 = ent["270deg_10um"]
      continue if ( !v11 || !v21 || !v31 || !v41)
      continue if ( !v12 || !v22 || !v32 || !v42)

      v1 = (parseFloat(v11)+parseFloat(v12))*1000 #mm -> um
      v2 = (parseFloat(v21)+parseFloat(v22))*1000 #mm -> um
      v3 = (parseFloat(v31)+parseFloat(v32))*1000 #mm -> um
      v4 = (parseFloat(v41)+parseFloat(v42))*1000 #mm -> um
      if j==0
        v1_start = v1
        v2_start = v2
        v3_start = v3
        v4_start = v4

      d1 = v1 - v1_start
      d2 = v2 - v2_start
      d3 = v3 - v3_start
      d4 = v4 - v4_start

      utime = Date.parse "#{ent["Date"]} #{ent["Time"]}"
      date = ent["Date"]
      time = ent["Time"]
      temp = ent["Temp"]

      data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at10deg",  "disp_um": parseFloat(d1) }
      data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at90deg",  "disp_um": parseFloat(d2) }
      data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at180deg", "disp_um": parseFloat(d3) }
      data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at270deg", "disp_um": parseFloat(d4) }

    #console.log data
    data

  @plot: (csv) ->
    gauge_data = @read_csv(csv)
    xdomain_gauge = d3.extent(gauge_data, (d) -> d.utime)
    ydomain_gauge = d3.extent(gauge_data, (d) -> d.disp_um)
    svg_gauge = append_svg("#menu_gauge")
    frame_gauge = make_frame(svg_gauge, "date", "displacement (um)", xdomain_gauge, ydomain_gauge, {xaxis_type: "time"})
    stroke_gauge = {at10deg:"#ed5454", at90deg:"#3874e3", at180deg:"#228b22", at270deg:"#ffa500" }
    fill_gauge   = {at10deg:"#f8d7d7", at90deg:"#bdd0f4", at180deg:"#9acd32", at270deg:"#ffead6" }
    makeScatterPlot frame_gauge, gauge_data, "utime", "disp_um",
                         { 
                           r: 3
                           fill: (d) -> fill_gauge[d.location]
                           stroke: (d) -> stroke_gauge[d.location]
                           stroke_width: "1px"
                         }
                         [
                           {label:"10deg",  stroke:'#ed5454', fill: "#f8d7d7", ypos:"66"},
                           {label:"90deg",  stroke:'#3874e3', fill: "#bdd0f4", ypos:"83"},
                           {label:"180deg", stroke:'#228b22', fill: "#9acd32", ypos:"100"},
                           {label:"270deg", stroke:'#ffa500', fill: "#ffead6", ypos:"117"}
                         ]
                         {
                           label: [ {data: [ "date", "time", (d) -> d.disp_um.toFixed(0)], separator:' ', postfix:' um'}]
                         }

class Loading
  @read_csv: (csv) ->
    data=[]
    for ent in csv
      d1 = ent["Date"]
      d2 = ent["Tension_kg"]
      continue if ( _.isEmpty(d1) || _.isEmpty(d2))
      #console.log("d1 " + d1)
      #console.log("d2 " + d2)
  
      utime = Date.parse(d1)
      #console.log("csv " + csv[i] + " Date " + d1 +  " utime " + utime);
      tension_kg = parseFloat(d2)
 
      data.push { utime: utime, tension_kg: tension_kg }
  
    #console.log("==Loading==")
    #console.log(data)
    data

  @plot: (csv, dailies) =>
    bar_data = @read_csv(csv)
    #for bar,j in bar_data
    #  console.log("j " + j)
    #  console.log("bar_data.utime " + bar.utime)
    #  console.log("bar_data.tension_kg " + bar.tension_kg)
    
    # daily    bar_data
    # 5/26     5/26
    # 5/27     6/23
    # 5/28     6/26
    # 5/29     
    # ....
    # 6/23
    # ....
    # 7/22
    for daily,i in dailies
      jnext = -1
      # search for bar_data until utime is larger than this daily.utime
      # Do not break
      for bar,j in bar_data
        #console.log("i " + i)
        #console.log("j " + j)
        #console.log("dailies.utime " + dailies[i].utime)
        #console.log("bar_data.utime " + bar_data[j].utime)
        #console.log("bar_data.tension_kg " + bar_data[j].tension_kg)
        if (bar.utime > daily.utime)
          jnext = j
          break
   
      #console.log("jnext #{jnext}")
      jnext = bar_data.length if (jnext==-1)
      daily.bar_tension_kg = bar_data[jnext-1].tension_kg
      daily.all_tension_kg = daily.wire_tension_kg + bar_data[jnext-1].tension_kg
  
  
    # Wire
    xdomain = d3.extent(dailies, (d) ->  d.utime)
    labelA = ((d) -> d.date)
    ydomain_wire = [0, dailies[dailies.length-1].wire_tension_kg]
    #/console.log(ydomain_wire)
    svg_wire = append_svg("#menu_load_wire")
    frame_wire = make_frame(svg_wire, "date", "loading of wires (kg)", xdomain, ydomain_wire, {xaxis_type: "time"})
    makeScatterPlot(frame_wire, dailies, "utime", "wire_tension_kg", { r: 3, stroke: "#ff1493", fill: "#ff69b4", stroke_width: "1px", line_stroke: "#ff1493" },[],
              { label: [ { data: [ labelA, ((d) -> "#{d.wire_tension_kg.toFixed(1)} kg")], separator:' '} ]})


    # TensionBar + Wire
    ydomain_all = [0.9*d3.min(dailies, (d) -> d.all_tension_kg), 1.1*d3.max(dailies, (d) -> d.all_tension_kg)]
    svg_all = append_svg("#menu_load_all")
    frame_all = make_frame(svg_all, "date", "total loading (kg)", xdomain, ydomain_all, {xaxis_type: "time"})
    makeScatterPlot(frame_all, dailies, "utime", "all_tension_kg", 
                                        { r: 3, fill: "#9966ff", stroke: "#6633cc", stroke_width: "1px", line_stroke: "#6633cc" }, [],
                                        { label: [ { data: [ labelA, ((d) -> "#{d.all_tension_kg.toFixed(1)} kg")], separator:' '} ]})
     
    # TensionBar
    ydomain_bar = [0.9*d3.min(dailies, ((d) -> d.bar_tension_kg)), 1.1*d3.max(dailies, ((d) -> d.bar_tension_kg))]
    #console.log("xdomain_bar " + xdomain_bar);
    #console.log("ydomain_bar " + ydomain_bar);
    svg_bar = append_svg("#menu_load_bar")
    frame_bar = make_frame(svg_bar, "date", "loading of tension bars (kg)", xdomain, ydomain_bar, {xaxis_type: "time"})
    makeScatterPlot(frame_bar, dailies, "utime", "bar_tension_kg", { r: 3, fill: "#0081B8", stroke: "blue", stroke_width: "1px", line_stroke: "blue"}, [],
                                         { label: [ { data: [ labelA, ((d) -> "#{d.bar_tension_kg.toFixed(1)} kg")], separator:' '} ]})


#xml_name = "test.xml";
#xml_name = "./xml/COMETCDC.xml";
#json_name = "./stats/stats.json";
#{"date":"2015/05/26","utime":1432566000000,"days":1,"num_sum":11,"num_sense":0,"num_field":11,"num_day":11,"num_ave":11.0,"num_bad":10,"wire_tension_kg":0.9997800000000001,"last_date":"2022/03/31","last_utime":1648652400000}


class Progress
  @plot: (dailies) ->

    # after 96 days, subtraced by 105
    # This is adhoc so do not forget to delete later
    dailies_subtract = _.map(dailies, (value, index, list) ->
      value.num_bad = value.num_bad - 105 if index >= 95
      value
    )
    #console.log("dalies_subtract")
    #console.log(dailies_subtract)


    #xdomain =  _.map(dailies, (d) ->d.days)
    xdomain = (d.days for d in dailies)
    ydomain_sum = [0, d3.max(dailies, (d) -> d.num_sum)]
    ydomain_day = [0, d3.max(dailies, (d) -> d.num_day)]
    ydomain_ave = [0, d3.max(dailies, (d) -> d.num_ave)]
    ydomain_bad = [0, d3.max(dailies_subtracted, (d) -> d.num_bad)]

    num_bins = 15
    day_space = xdomain.length / num_bins
    day_space = parseInt(day_space)
    console.log("num_bins #{num_bins}")
    console.log("day_space #{day_space}")
    console.log("xdomain.length #{xdomain.length}")
    xaxis_tickValues = (d.days for d in dailies by day_space)
    console.log("xaxis_tickValues #{xaxis_tickValues}")
  
    svg_progress_sum = append_svg("#menu_progress #progress_sum")
    svg_progress_day = append_svg("#menu_progress #progress_day")
    svg_progress_ave = append_svg("#menu_progress #progress_ave")
    svg_progress_bad = append_svg("#menu_progress #bad_wires")
  
    frame_progress_sum = make_frame(svg_progress_sum, "days", "total # of stringed wires",     xdomain, ydomain_sum, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues})
    frame_progress_day = make_frame(svg_progress_day, "days", "# of stringed wires",           xdomain, ydomain_day, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues})
    frame_progress_ave = make_frame(svg_progress_ave, "days", "ave # of stringed wires",       xdomain, ydomain_ave, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues})
    frame_progress_bad = make_frame(svg_progress_bad, "days", "# of wires to be re-stringed",  xdomain, ydomain_bad, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues})
  
    $("#last_day").html("Finished on "+new Date(_.last(dailies).last_utime).toLocaleDateString("ja-JP"))
    makeBarChart(frame_progress_sum, dailies, "days","num_sum", "#D70071", {label: [ {data: ["num_sum"]} ]})
    makeBarChart(frame_progress_ave, dailies, "days","num_ave", "#91D48C", {label: [ {data: [(d)->d.num_ave.toFixed(1)]} ]})
    makeBarChart(frame_progress_day, dailies, "days","num_day", "steelblue", {label: [ {data: ["num_day"]} ]})
    makeBarChart(frame_progress_bad, dailies_subtract, "days","num_bad", "#6521A0", {label: [ {data: ["num_bad"]} ]})

  @plotLayerDays = (data) ->
    #console.log(data)
    #{"dataID":2,"layerID":37,"wireID":2,"tBase":"80","density":3.359e-09,"date":"2015/06/12","freq":49.89,"tens":78.6}
    layerData = _.groupBy(data, (d) -> parseInt(d.layerID))
    #console.log("==layerData==")
    #console.log(layerData)
    layerNumbers = _.keys(layerData)
    xmin = _.min(layerNumbers, _.identity)
    xmax = _.max(layerNumbers, _.identity)
    xmin = parseInt(xmin)
    xmax = parseInt(xmax)
    #console.log("layerNumbers "+ layerNumbers);
    #console.log("xmin "+ xmin);
    #console.log("xmax "+ xmax);
    #mydata = _.range(1,40).map((d)-> {layerID: d, num_days: 0})
    mydata = ({layerID: d, num_days: 0} for d in [1..39])
    #console.log(mydata)
    _.each layerData, (v, layerID) -> 
       days = _.groupBy(v, (d2) -> d2.date)
       #console.log(layerID)
       #console.log(days)
       #console.log(mydata[layerID-1])
       num_days = _.keys(days).length
       #console.log(_.keys(days).length)
       mydata[layerID-1].layerID = layerID
       mydata[layerID-1].num_days = num_days
           
    #console.log(JSON.stringify(mydata))
    svg = append_svg("#menu_progress #layer_days")
    #console.log("xdomain->")
    #//var xdomain = _.range(xmin,xmax+1)
    #xdomain = _.range(0,40)
    xdomain = (x for x in [0..40])
    #//console.log(xmax+1)
    #//console.log(xdomain)
    #//console.log(mydata)
    ydomain = [0, 10]
    #xaxis_tickValues = _.range(0,40,5)
    xaxis_tickValues = (x for x in [0..40] by 5)
    frame = make_frame(svg, "layer_id", "days", xdomain, ydomain, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues})
    makeBarChart(frame, mydata, "layerID","num_days", "#A8BE62", {label: [ {data: ["layerID"], prefix: 'layer_id '}, {data: ["num_days"], postfix: ' days'} ]})
       

class Endplate
  @plot: (data, current) ->
    svg = d3.select("#menu_status #status").append("svg").attr({width:w, height:h})
    svg.selectAll("circle")
       .data(holes)
       .enter()
       .append("circle")
       .attr("cx", ((d) -> d.x/diam*w*0.9 + w/2.0))
       .attr("cy", ((d) -> -d.y/diam*h*0.9 + h/2.0))
       .attr("r", 0.5)
       .attr("flll", "gray")

    svg.selectAll("circle.hoge")
        .data(data)
        .enter()
        .append("circle")
        #.on("mouseover", (d) -> d3.select(this).attr("fill", "orange"))
        #.on("mouseout", (d) -> d3.select(this).attr("fill", "red") )
        #.on "click", (d) ->
        #         rs = d3.select(this).attr("r");
        #         d3.select("body").select("p").text(rs);
        .attr("cx", (d) -> +get_xypos(d.layerID, d.wireID, numWires[d.layerID-1])["x"]/diam*w*0.9 + w/2)
        .attr("cy", (d) -> -get_xypos(d.layerID, d.wireID, numWires[d.layerID-1])["y"]/diam*h*0.9 + h/2)
        .attr("r",  (d) -> 0)
        .transition()
        .delay((d,i) -> (1000/data.length)*i)
        .duration(3000)
        .attr("r", (d) -> 1.5)
        .attr("stroke", (d) -> (d.tbase=="50")?"#f8d7d7":"#bdd0f4")
        .attr("fill",   (d) -> if (d.tBase=="50") then "#ed5454" else "#3874e3")
        .attr("stroke_width", "1px")
        .each "end", ->
            #r1 = parseFloat(current_num_layers/39.0*100).toFixed(0)
            r2 = parseFloat(current.num_sum/numTotalWires*100).toFixed(0)
            r3 = parseFloat(current.num_sense/4986*100).toFixed(0)
            r4 = parseFloat(current.num_field/14562*100).toFixed(0)
  
            #Show status
            texts=[
              "Days: #{current.days} (#{current.date})"
              #"Layer: "+r1+"% ("+current_num_layers+"/39)",
              "Wire:  #{r2}% (#{current.num_sum}/#{numTotalWires})"
              "Sense: #{r3}% (#{current.num_sense}/4986)"
              "Field: #{r4}% (#{current.num_field}/14562)"]
  
            svg.selectAll("text")
               .data(texts)
               .enter()
               .append('text')
               .text((txt) -> txt)
               .attr("x",(_, i) -> w*1.1/3.0)
               .attr("y", (_, i) -> h/2.5+(i+1.0)*25)
               .attr("font-family", "HelveticaNeue-Light")
               .attr("font-style", "italic")
               .attr("font-size", (_,i) -> if i==0 then "20px" else "20px" )
               .attr("text-anchor", (_,i) -> if i==0 then "start" else "start")
               .attr("fill", "none")
               .transition()
               .duration(1000)
               .ease("linear")
               .attr("fill", (_, i) -> if i==2 then "#ed5454" else if i==3 then "#3874e3" else "black")
               

g_layerCheckList = []
class LayerSelection
  @plot: (data) ->
    g_layerCheckList = (true for i in [0..38])
    layer_selection = ({layerid: i} for i in [1..39])
    
    #console.log("layer_selection");
    #console.log(layer_selection);
    labels = d3.select("#menu_tension")
               .append("div")
               .html("LayerID")
               .attr("id","layer_selection")
               .selectAll(".test")
               .data(layer_selection)
               .enter()
               .append("label")
               .attr("class", "label_id_layers")
               .text((d) -> d.layerid)
               .insert("input")
               .attr("type", "checkbox")
               .property("checked", true)
               .attr("id", (d) -> "id_layer_" + d.layerid)
               .attr("value", (d) -> d.layerid)
               .on "click", (d) -> 
                 chk = d3.select(this).property("checked")
                 msg = "layer #{d.layerid} -> #{chk}"
                 g_layerCheckList[d.layerid-1] = chk
                 #console.log(msg);
                 Tension.plot(data)
                 TensionHistogram.plot(data, "sense")
                 TensionHistogram.plot(data, "field")
  
    p = d3.select("#menu_tension")
          .append("p")
          .attr("id","layer_selection")
  
    texts = ["checkall","uncheckall"]
    p.insert("select")
     .attr("id","layer_selection2")
     .selectAll(".dummy")
     .data(texts)
     .enter()
     .append("option")
     .attr("value", (d) -> d)
     .append("text").text((d) -> d)
  
    d3.select("#layer_selection2")
      .on "change", (d) ->
        val = d3.select(this).property("value")
        #console.log("val -> "+ val)
        chk = if (val=="checkall") then true else false
        labels.property("checked",chk)
        g_layerCheckList = (chk for i in [0...39])
        #console.log("changed")
        Tension.plot(data)
        TensionHistogram.plot(data,"sense")
        TensionHistogram.plot(data,"field")


class Tension
  @first_call = true
  @plot: (data) ->
    if @first_call
      #console.log("Tension: @plot data")
      #for d in data
      #  console.log "d.wireID #{d.wireID}"
      #console.log("Tension: xdomain_tension #{d3.max(data, (d) -> parseInt(d.wireID))}")
      xdomain_tension = [0, d3.max(data, (d) -> parseInt(d.wireID))]
      ydomain_tension = [0, d3.max(data, (d) -> parseFloat(d.tens))]
      svg_tension = append_svg("#menu_tension")
      @frame_tension = make_frame(svg_tension, "wire_id", "tension (g)", xdomain_tension, ydomain_tension, {xaxis_type: "linear"})
      LayerSelection.plot(data)
      @first_call = false

    xmin = d3.min(data, (d) -> parseInt(d.wireID))
    xmax = d3.max(data, (d) -> parseFloat(d.wireID))
    makeLine(@frame_tension, "tension_limit_sense", [ { x:xmin, y: 45}, {x:xmax, y: 45} ])
    makeLine(@frame_tension, "tension_limit_sense", [ { x:xmin, y: 55}, {x:xmax, y: 55} ])
    makeLine(@frame_tension, "tension_limit_field", [ { x:xmin, y: 72}, {x:xmax, y: 72} ])
    makeLine(@frame_tension, "tension_limit_field", [ { x:xmin, y: 88}, {x:xmax, y: 88} ])
  
    #console.log(layerCheckList);
    data_select = _.filter data, (d) ->
      #console.log(layerCheckList[d.layerID-1])
      g_layerCheckList[d.layerID-1]
  
    #console.log("data->");
    #console.log(data);
    #console.log("data_select-> " + data_select.length);
    #console.log(data_select);
    makeScatterPlot @frame_tension, data_select, "wireID", "tens", 
                {
                  r: 3
                  stroke: ((d) -> if (d.tBase=="80") then "#3874e3" else "#ed5454"),
                  fill:   ((d) -> if (d.tBase=="80") then "#bdd0f4" else "#f8d7d7"),
                  stroke_width: (d) -> if (d.tens<d.tBase*0.9 || d.tens>d.tBase*1.1) then "1px" else "0px"
                },
                [
                  {label:"sense", stroke:"#ed5454", fill:"#f8d7d7", ypos:"15"}
                  {label:"field", stroke:"#3874e3", fill:"#bdd0f4", ypos:"30"}
                ],
                {label: [ {data: ["date"] }
                          {data: ["layerID", "wireID"], separator: '-'}
                          {data: ["tens"], postfix:' g'} ]
                }


class TensionHistogram 
  @svg_tension_hist = {}
  @frame_tension_hist = {}
  @first_call_hist = {"sense":true, "field":true}

  @plot: (data, sense_or_field) ->
    #console.log("plotTensionHistogram");
    # count entries
    nx = 20
    if sense_or_field=="sense"
      xmin = 40
      xmax = 60
    else
      xmin = 68
      xmax = 88

    xstep = (xmax - xmin)/nx
    xdomain = (x for x in [xmin..xmax] by xstep)
    tick_list = (tick for tick in [0..nx] by 2)
    xaxis_tickValues = (xdomain[tick] for tick in tick_list)
    #xdomain = _.range(xmin, xmax, xstep)
    #tick_list = _.range(0, nx, 2)
    #xaxis_tickValues = _.map(tick_list, (d) -> xdomain[d])
    #console.log("xdomain");
    #console.log(xdomain);
    #console.log("xaxis_tickValues");
    #console.log(xaxis_tickValues);

    # test data
    #data_select = [
    #   {tens:70},
    #   {tens:72},
    #   {tens:78},
    #   {tens:73},
    #   {tens:71},
    #   {tens:70},
    #   {tens:85},
    #   {tens:81}
    #]
    data_select = _.filter data, (d) ->
      is_sense = d.tBase=="50"
      is_field = d.tBase=="80"
      if is_sense && sense_or_field isnt "sense"
        return false
        #console.log("is_sense " + is_sense + " d.tBase " + d.tBase);
      else if is_field && sense_or_field isnt "field"
        return false
        #console.log(layerCheckList[d.layerID-1]);
      else 
        return g_layerCheckList[d.layerID-1]

    #console.log("===data_select==")
    #console.log(data_select)

    entries = _.countBy(data_select, (d) -> Math.floor((d.tens - xmin)/xstep))
    bindatum = _.map(xdomain, (e, i) -> {itens: xdomain[i], ents: if entries[i]? then entries[i] else 0})

    ydomain = [0, d3.max(bindatum, (d) -> d.ents)]
    #console.log("xdomain");
    #console.log(xdomain);
    #console.log("entries");
    #console.log(entries);
    #console.log("bindatum");
    #console.log(bindatum);
    #console.log("ydomain");
    #console.log(ydomain);
    if @first_call_hist[sense_or_field]
      d3.select("#menu_tension").append("div").attr("id","menu_tension_#{sense_or_field}")
      @svg_tension_hist[sense_or_field] = append_svg("#menu_tension_#{sense_or_field}")
      @first_call_hist[sense_or_field] = false

    @frame_tension_hist[sense_or_field] = make_frame(@svg_tension_hist[sense_or_field], "tension (g)", "#/g", xdomain, ydomain, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues})
    makeBarChart(@frame_tension_hist[sense_or_field], bindatum, "itens","ents", (-> if (sense_or_field=="sense") then "#ed5454" else "#3874e3"), {label: [ {data: ["ents"]} ]})
    tension_mean = _.reduce(data_select, ((memo, d) -> memo + parseFloat(d.tens)), 0) /data_select.length
    tension_rms =  _.reduce(data_select, ((memo, d) -> memo + Math.pow(parseFloat(d.tens)-tension_mean,2)), 0) /data_select.length
    tension_rms = Math.sqrt(tension_rms)
    frac_rms = (tension_rms/tension_mean*100).toFixed(0)
    makeStatBox(@frame_tension_hist[sense_or_field], w-250, 20, "Mean #{tension_mean.toFixed(2)} g")
    makeStatBox(@frame_tension_hist[sense_or_field], w-250, 40, "Rms #{tension_rms.toFixed(2)} g (#{frac_rms} %)")


class TempHumid
  @plot : (inside, outside) ->
    data = inside.concat(outside)
    svg_temp = append_svg("#menu_temp")
    svg_humid = append_svg("#menu_temp")
    xdomain = d3.extent(data,  (d) -> d.utime)
    ydomain_temp = d3.extent(data, (d) -> d.temp)
    ydomain_humid = d3.extent(data, (d) -> d.humid)
    frame_temp  = make_frame(svg_temp, "date", "temperature (C)", xdomain, ydomain_temp, {xaxis_type: "time"})
    frame_humid = make_frame(svg_humid, "date", "humidity (%)", xdomain, ydomain_humid, {xaxis_type: "time"})
    stroke = {in:"#ed5454", out:"#3874e3"}
    makeScatterPlot frame_temp, data, "utime", "temp",
                         { 
                           r: 1
                           fill: (d) -> "none"
                           stroke: (d) -> stroke[d.location]
                           stroke_width: "1px"
                         }
                         [
                           {label:"inside",  stroke:'#ed5454', fill: "none", ypos:"66"},
                           {label:"outside", stroke:'#3874e3', fill: "none", ypos:"83"},
                         ]
                         {
                           label: [ {data: [ "date", (d) -> d.temp], separator:' ', postfix:' C'}]
                         }

    makeScatterPlot frame_humid, data, "utime", "humid",
                         { 
                           r: 1
                           fill: (d) -> "none"
                           stroke: (d) -> stroke[d.location]
                           stroke_width: "1px"
                         }
                         [
                           {label:"inside",  stroke:'#ed5454', fill: "none", ypos:"66"},
                           {label:"outside", stroke:'#3874e3', fill: "none", ypos:"83"},
                         ]
                         {
                           label: [ {data: [ "date", (d) -> d.humid], separator:' ', postfix:' %'}]
                         }


$ ->

  spinner = new Spinner(spin_opts).spin($("#status").get(0))

  s3 = new S3()

  #$("#upload-csv #upload-form-file").change ->
  #  #console.log "called onFileInput"
  #  item = @files[0]
  #  reader = new FileReader()
  #  reader.onload = onFileLoadCSV
  #  reader.readAsText(item)
  #  return

  #onFileLoadCSV = (e) -> 
  #  body = e.target.result
  #  #console.log body


  $("#upload-xml #upload-form-file").change ->
    #console.log "called onFileInput"
    file = @files[0]
    $(name + " #error").html("")
    $(name + " #error").hide()
    console.log("file.name -> ", file.name)
    if (file.name!="COMETCDC.xml")
      console.log("filename is incorrect")
      return
    
    reader = new FileReader()
    reader.onload = onFileLoad
    reader.readAsText(file)
    return

  # Date will be determined after reading XML file
  today_date = "2015/07/27" # for debug
  today_dir  = "20150727" # for debug

  onFileLoad = (e) -> 
    parser = new DOMParser()
    xmlDoc = parser.parseFromString(e.target.result, "text/xml")
    #console.log xmlDoc

    # daily_data
    [today_date, today_dir, daily_data] = make_daily_data(xmlDoc)
    console.log("TODAY: #{today_date} #{today_dir}")

    daily_dir = "daily/#{today_dir}"
    current_dir = "daily/current" # copy of daily_dir
    stats_dir = "stats"

    #console.log("uploading data.json")
    s3.putObjectWithProgress "#{daily_dir}/data.json", JSON.stringify(daily_data),
      "#upload-xml",
      "#upload-json-daily-data #progress_msg",
      "#upload-json-daily-data #progress_bar"

    s3.putObjectWithProgress "#{current_dir}/data.json", JSON.stringify(daily_data),
      "#upload-xml",
      "#upload-json-current-data #progress_msg",
      "#upload-json-current-data #progress_bar"

    # daily_stat
    s3.getJSON_prev_stat today_dir, (prev_stat) ->
      #console.log("getJSON_prev_stat is called!!!")
      #console.log(prev_stat)
      daily_stat = make_stat(today_date, prev_stat, daily_data)
      s3.putObjectWithProgress "#{daily_dir}/stat.json", JSON.stringify(daily_stat),
        "#upload-xml",
        "#upload-json-daily-stat #progress_msg",
        "#upload-json-daily-stat #progress_bar"

      s3.putObjectWithProgress "#{current_dir}/stat.json", JSON.stringify(daily_stat),
        "#upload-xml",
        "#upload-json-current-stat #progress_msg",
        "#upload-json-current-stat #progress_bar"

      # stats
      s3.getJSON_stats (prev_stats) ->
        #console.log("getJSON_prev_stats is called!!!")
        # do not add if date is same.
        #console.log("_.last(prev_stats).date #{_.last(prev_stats).date}")
        #console.log("daily_stat.date #{daily_stat.date}")
        if _.last(prev_stats).date isnt daily_stat.date
          stats = prev_stats.concat(daily_stat) if prev_stats.date isnt daily_stat.date
          s3.putObjectWithProgress "#{stats_dir}/stats.json", JSON.stringify(stats),
            "#upload-xml",
            "#upload-json-stats #progress_msg",
            "#upload-json-stats #progress_bar"
        else
          console.log("will not upload stats.json because stats = prev_stats.concat(daily_stat)")

    return


  zipWrapper "#upload-xml #upload-form-file", (blob) -> 
    console.log("starting ajax...")
    console.log("blog: " + blob)
    s3.putObjectWithProgress "zip/#{today_dir}/COMETCDC.zip", blob, 
      "#upload-xml #upload-form-file",
      "#upload-xml #progress_msg",
      "#upload-xml #progress_bar"


  s3.getObject "csv/dial_gauge.csv", (url) ->
    d3.csv url, (error, csv) ->
      DialGauge.plot(csv)

  s3.getObject "stats/stats.json", (url) ->
    d3.json url, (error, dailies) ->
      #console.log(dailies)

      Progress.plot(dailies)

      s3.getObject "csv/tension_bar.csv", (url) ->
       d3.csv url, (error, csv) ->
         Loading.plot(csv, dailies)

      s3.getObject "daily/current/data.json", (url) ->
        d3.json url, (error, data) ->
          #console.log("daily/current/data.json")
          #console.log(data)
          Progress.plotLayerDays(data)

          spinner.stop()

          Endplate.plot(data, dailies[dailies.length-1])
          Tension.plot(data)
          TensionHistogram.plot(data,"sense")
          TensionHistogram.plot(data,"field")

  s3.getObject "csv/inside.json", (url) ->
    d3.json url, (error, inside) ->
      s3.getObject "csv/outside.json", (url) ->
        d3.json url, (error, outside) ->
          TempHumid.plot(inside, outside)

