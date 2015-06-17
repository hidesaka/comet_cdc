$(function () {
      var debug=false;

      // setup s3
      var awsRegion = "us-east-1";
      var cognitoParams = {
         IdentityPoolId: "us-east-1:435dfdc9-d483-4f5e-8f8b-27e3569ad9af"
      };

      AWS.config.region = awsRegion;
      AWS.config.credentials = new AWS.CognitoIdentityCredentials(cognitoParams);
      AWS.config.credentials.get(function(err) {
            if (!err) {
               console.log("Cognito Identity Id: " + AWS.config.credentials.identityId);
            }
      });
      var s3BucketName = "comet-cdc";
      var s3RegionName = "ap-northeast-1"
      var s3 = new AWS.S3({params: {Bucket: s3BucketName, Region: s3RegionName}});
      console.log("=== s3 ====");
      console.log(s3);
      console.log("===========");

      var first_call=true;
      var first_call_hist={"sense":true, "field":true};
      var diam = 180;
      var w = 650;
      var h = 650;

      var margin = {top: 20, right: 150, bottom: 50, left: 80};
      var width = w - margin.left - margin.right;
      var height = 300 - margin.top - margin.bottom;

      var numWires = [ 
         396, 396, 396, 408, 408, 420, 420,
         432, 432, 444, 444, 456, 456, 468, 
         468, 480, 480, 492, 492, 504, 504, 
         516, 516, 528, 528, 540, 540, 552, 
         552, 564, 564, 576, 576, 588, 588, 
         600, 600, 612, 612
      ];
      var numTotalWires = _.reduce(numWires, function(memo, num) { return memo+num; });

      var get_xypos = function(layerid, wireid, num_wires) {
         var r = 50+(layerid-1);
         var deg = (wireid-1)/num_wires*360;
         var rad = deg/180.*Math.PI;
         var x = r*Math.cos(rad);
         var y = r*Math.sin(rad);
         return {x: x, y: y};
      }

      var holes = [];
      for (i=0; i<numWires.length; i++) {
         for (j=0; j<numWires[i]; j++) {
            holes.push(get_xypos(i+1, j+1, numWires[i]));
         }
      }

      var append_svg = function(id) {
         return  d3.select(id).append("svg")
         .attr("width", width + margin.left + margin.right)
         .attr("height", height + margin.top + margin.bottom)
         .append("g")
         .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
      };

      var make_frame = function(svg, xtitle, ytitle, xdomain, ydomain, options) {
         svg.selectAll("g").remove();

         var xScale;
         if (options.xaxis_type=="roundBands") {
            //console.log("select xaxis roundBands");
            xScale = d3.scale.ordinal().domain(xdomain).rangeRoundBands([0, width]);
         } else if (options.xaxis_type=="time") {
            //console.log("select xaxis time");
            xScale = d3.time.scale().domain(xdomain).range([0, width]).nice();
         } else {
            //console.log("select xaxis linear");
            xScale = d3.scale.linear().domain(xdomain).range([0, width]);
         }
         var yScale = d3.scale.linear().domain(ydomain).range([height, 0]).nice();

         if (!options.no_axis) {
            var tick_label_dx = 0;
            var tick_label_dy = 10;
            var tick_label_rotate = "0";
            var xAxis = d3.svg.axis().scale(xScale).orient("bottom");
            if (typeof options.xaxis_tickValues !== 'undefined' && options.xaxis_tickValues!='') {
               //console.log(options.xaxis_tickValues);
               xAxis.tickValues(options.xaxis_tickValues);
            }
            if (options.xaxis_type=="time") {
               xAxis.ticks(5).tickFormat(d3.time.format('%b %d'));
               tick_label_rotate = "-65";
               tick_label_dx = -30;
               tick_label_dy = -1;
            }
            var yAxis = d3.svg.axis().scale(yScale).orient("left");

            var xx = svg.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(0," + height + ")")
            .call(xAxis);
            xx.selectAll("text")
            .attr("transform", "rotate("+tick_label_rotate+")")
            .attr("text-anchor", "start")
            .attr("dx", tick_label_dx)
            .attr("dy", tick_label_dy)
            xx.append("text")
            .attr("x", width+8)
            .attr("y", 10)
            .attr("text-anchor", "start")
            .text(xtitle);

            svg.append("g")
            .attr("class", "axis")
            .call(yAxis)
            .append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", -55)
            .attr("dy", ".71em")
            .style("text-anchor", "end")
            .text(ytitle);
         }

         return { "svg": svg, "xScale": xScale, "yScale": yScale };
      };

      var makeBarChart = function (frame, data, xdata, ydata, fillColor, tooltip) {
         frame.svg.selectAll("rect").remove();

         frame.svg.selectAll(".bar")
         .data(data)
         .enter().append("rect")
         .attr("fill",fillColor)
         .attr("x", function(d) { return frame.xScale(d[xdata]); })
         .attr("width", frame.xScale.rangeBand()*0.97)
         //.attr("width", frame.xScale.rangeBand() - 5)
         .attr("y", height)
         .attr("height", 0)
         .transition()
         .duration(1000)
         .attr("y", function(d, i) { return frame.yScale(d[ydata]); })
         .attr("height", function(d) { return height - frame.yScale(d[ydata]); });

         if (tooltip) {
            makeTooltip(frame, "rect", data, xdata, ydata, tooltip.label);
         }
      };


      var makeScatterPlot = function (frame, data, xdata, ydata, options, legend_entry, tooltip) {

         if (options.line_stroke) {
            var line = d3.svg.line()
            .x(function(d) { return frame.xScale(d[xdata]); })
            .y(function(d) { return frame.yScale(d[ydata]); })

            frame.svg.append("path")
            .attr("stroke", options.line_stroke)
            .attr("fill", "none")
            .attr("d", line(data));
         }

         frame.svg.selectAll("circle").remove();

         if (legend_entry.length!=0) {
            // add legend   

            var legend = frame.svg.append("g")
            .attr("x", width - 65)
            .attr("y", 25)
            .attr("height", 100)
            .attr("width", 100)
            .selectAll("text")
            .data(legend_entry)
            .enter()
            .append("text")
            .attr("x", w-180)
            .attr("y", function(d) { return d.ypos; })
            .attr("height",30)
            .attr("width",100)
            .style("fill", function(d) { return d.stroke; })
            .text(function(d) { return d.label; });

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
            .attr("cy", function(d) { return d.ypos - 4; })
            .attr("r", 3)
            .attr("fill", function(d) { return d.fill; })
            .attr("stroke",function(d) { return d.stroke; })
            .attr("stroke-width", "1px");
         }

         frame.svg.selectAll(".circle")
         .data(data)
         .enter()
         .append("g")
         .attr("class","dot") // Need to distinguish from circle for legend
         .append("circle")
         .attr("cx", function(d,i) { return frame.xScale(d[xdata]); })
         .attr("cy", function(d,i) { return frame.yScale(d[ydata]); })
         .attr("r",  3)
         .attr("fill", options.fill)
         .attr("stroke",options.stroke)
         .attr("stroke-width", options.stroke_width);

         if (tooltip) {
            makeTooltip(frame, ".dot circle", data, xdata, ydata, tooltip.label);
         }
      };

      var makeLine = function (frame, class_name, points) {
         var line = d3.svg.line().x(function(d) { return frame.xScale(d.x); }).y(function(d) { return frame.yScale(d.y); });
         frame.svg.append("path").datum(points).attr("class", class_name).attr("d", line);
      };

      var makeStatBox = function(frame, x, y, text) {
         frame.svg.select("text").remove();

         frame.svg.append("text")
         .attr("x", x)
         .attr("y", y)
         .text(text);
      };

      var makeTooltip = function (frame, class_name, data, xdata, ydata, labels) {

         var focus = frame.svg.append("g").attr("class","focus").style("display","none");
         //focus.append("rect").attr("opacity","0.6").attr("x",9).attr("y",9).attr("rx",2).attr("ry",2).attr("width",30).attr("height",20);
         focus.append("rect").attr("opacity","0.6").attr("x",9).attr("y",9).attr("rx",2).attr("ry",2).attr("width",30)
         .attr("height",function() {
               if (labels.length==1) return 20;
               else return labels.length*17;
         });

         focus.selectAll("text").data(labels).enter().append("text")
         .attr("x", 14)
         .attr("y", 12)
         .attr("font-family", "Inconsolata")
         .attr("font-size", "10px")
         .attr("fill", "white");

         var get_msg = function(d, label, i) {
            var msg = label.prefix || '';
            for (var i=0; i<label.data.length; i++) {
               if (typeof(label.data[i])=='function') {
                  msg += label.data[i](d);
               } else {
                  msg += d[label.data[i]];
               }
               if (i<label.data.length-1) msg += label.separator || '';
            }
            msg += label.postfix || '';

            return msg;
         };

         frame.svg.selectAll(class_name)
         .data(data)
         .on("mouseover", function() { focus.style("display", null); })
         .on("mouseout", function() { focus.style("display", "none"); })
         .on("mousemove", function(d) {
               var xval = (typeof(xdata)=='function')? xdata(d): d[xdata];
               var yval = (typeof(ydata)=='function')? ydata(d): d[ydata];
               focus.select("rect").attr("transform", "translate(" + frame.xScale(xval) + "," + (frame.yScale(yval)-10) + ")");
               focus.select("rect").attr("width", function() {
                     var line = [];
                     focus.selectAll("text").each(function(label, i) { 
                           line.push(get_msg(d, label, i));
                     });
                     var max_len = d3.max(line, function(d) { return d.length; });
                     //console.log(line);
                     return 14+max_len*4.7;
               });
               focus.selectAll("text").attr("transform", function(_,i) { return "translate(" + frame.xScale(xval) + "," +  (frame.yScale(yval)+i*15) + ")"; });
               focus.selectAll("text").text(function(label,i) {
                     return get_msg(d, label, i);
               });
         });
      };

      var plotWires_new = function (data, current) {

         var i, j;
         for (i=0; i<data.length; i++) {

            data[i].xpos =  +get_xypos(data[i].layerID, data[i].wireID, numWires[data[i].layerID-1])["x"]/diam*w*0.9 + w/2;
            data[i].ypos =  -get_xypos(data[i].layerID, data[i].wireID, numWires[data[i].layerID-1])["y"]/diam*h*0.9 + h/2;

         }
         console.log("data[0]");
         console.log(data[0]);

         var xdomain_wires = d3.max();
         var svg_wires = append_svg("#menu_status #status");
         var frame_wires = make_frame(svg_wires, "", "", xdomain_wires, ydomain_wires, {xaxis_type: "linear"});

         makeScatterPlot(frame_wires, data, "xpos", "ypos", {
               //stroke: function(d) { return (d.tBase==80)?"#3874e3":"#ed5454"; }, 
               fill:   function(d) { return (d.tBase=="50")?"#ed5454":"#3874e3" },
               stroke_width: "px"
            }, [
               //{label:"sense", fill:"red", ypos:"82"}, 
               //{label:"field", fill:"blue", ypos:"25"}
            ], {
               //label: [ 
               //   {data: ["date"] }, 
               //   {data: ["layerID", "wireID"], separator: '-'}, 
               //   {data: ["tens"], postfix:' g'} ], 
               options: {width: "70", height: "50"}
         });
      };

      var plotWires = function (svg, data, current) {
         svg.selectAll("circle.hoge")
         .data(data)
         .enter()
         .append("circle")
         .on("mouseover", function(d) { 
               //d3.select(this).attr("fill", "orange");
         })
         .on("mouseout", function(d) { 
               //d3.select(this).attr("fill", "red");
         })
         .on("click", function(d) {
               //   var rs = d3.select(this).attr("r");
               //   d3.select("body").select("p").text(rs);
         })
         .attr({
               cx: function(d) { return +get_xypos(d.layerID, d.wireID, numWires[d.layerID-1])["x"]/diam*w*0.9 + w/2; },
               cy: function(d) { return -get_xypos(d.layerID, d.wireID, numWires[d.layerID-1])["y"]/diam*h*0.9 + h/2; },
               r: function(d) { return 0; }
         })
         .transition()
         .delay(function(d,i) { return (1000/data.length)*i; })
         .duration(3000)
         .attr({
               r: function(d) { return 1.5; },
               //stroke: function(d) { return (d.tbase=="50")?"#f8d7d7":"#bdd0f4" },
               fill: function(d) { return (d.tBase=="50")?"#ed5454":"#3874e3" },
               "stroke_width": "1px"
         })
         .each("end", function() {

               //var r1 = parseFloat(current_num_layers/39.0*100).toFixed(0);
               var r2 = parseFloat(current.num_sum/numTotalWires*100).toFixed(0);
               var r3 = parseFloat(current.num_sense/4986*100).toFixed(0);
               var r4 = parseFloat(current.num_field/14562*100).toFixed(0);

               // Show status
               var texts=[
                  "Days: "+current.days + ' (' + current.date + ')',
                  //"Layer: "+r1+"% ("+current_num_layers+"/39)",
                  "Wire:  "+r2+"% ("+current.num_sum+"/"+numTotalWires+")",
                  "Sense: "+r3+"% ("+current.num_sense+"/4986)",
                  "Field: "+r4+"% ("+current.num_field+"/14562)"];

               svg.selectAll("text")
               .data(texts)
               .enter()
               .append('text')
               .text(function(txt) { return txt; })
               .attr({
                     x: function(_, i) { return w*1.1/3.0; },
                     y: function(_, i) { return h/2.5+(i+1.0)*25; },
                     "font-family": "HelveticaNeue-Light",
                     //"font-style": "italic",
                     "font-size": function(_,i) { return (i==0)?"20px":"20px"; },
                     "text-anchor": function(_,i) { return (i==0)?"start":"start"; },
                     "fill": "none"
               })
               .transition()
               .duration(1000)
               .ease("linear")
               .attr({
                     "fill": function(_, i) { 
                        var col="black";
                        if (i==2) { 
                           col="#ed5454"; 
                        } else if (i==3) { 
                           col="#3874e3"; 
                        } 
                        return col; 
                     }
               });
         });
      };

      var layerCheckList = _.map(_.range(39), function(i) { return true; });
      //var layerCheckList = _.map([1, 2, 3], function(num){ return num * 3; });
      //var layerCheckList = [1,2,3];
      //console.log("first-> " + layerCheckList.length);
      //console.log(layerCheckList);
      var plotLayerSelection = function(data) {
         var layer_selection=[];
         for (i=1; i<=39; i++) {
            layer_selection[i-1] = {layerid: i};
         }
         //console.log("layer_selection");
         //console.log(layer_selection);
         var labels = d3.select("#menu_tension").
         append("div")
         .html("LayerID")
         .attr("id","layer_selection")
         .selectAll(".test")
         .data(layer_selection)
         .enter()
         .append("label")
         .attr("class", "label_id_layers")
         .text(function(d) { return d.layerid; })
         .insert("input")
         .attr("type", "checkbox")
         .property("checked", true)
         .attr("id", function(d) { return "id_layer_" + d.layerid; })
         .attr("value", function(d) { return d.layerid; })
         .on("click", function(d) {
               var chk = d3.select(this).property("checked");
               var msg = "layer " + d.layerid + " -> " + chk;
               layerCheckList[d.layerid-1]=chk;
               //console.log(msg);
               plotTension(data);
               plotTensionHistogram(data, "sense");
               plotTensionHistogram(data, "field");
         });

         var p = d3.select("#menu_tension").
         append("p")
         .attr("id","layer_selection");

         var texts = ["checkall","uncheckall"];
         p.insert("select")
         .attr("id","layer_selection2")
         .selectAll(".dummy")
         .data(texts)
         .enter()
         .append("option")
         .attr("value", function(d) { return d; })
         .append("text").text(function(d) { return d; })

         d3.select("#layer_selection2")
         .on("change", function(d) {
               var val = d3.select(this).property("value");
               //console.log("val -> "+ val);
               var chk = (val=="checkall")?true:false;
               labels.property("checked",chk);
               for (var i=0; i<39; i++) {
                  layerCheckList[i] = chk;
               }
               //console.log("changed");
               plotTension(data);
               plotTensionHistogram(data,"sense");
               plotTensionHistogram(data,"field");
         });


         return labels;
      };

      var lables;
      var frame_tension;
      var plotTension = function(data) {
         var i;

         if (first_call) {
            var xdomain_tension = [0, d3.max(data, function (d) { return d.wireID; })];
            var ydomain_tension = [0, d3.max(data, function (d) { return d.tens; })];
            svg_tension = append_svg("#menu_tension");
            frame_tension = make_frame(svg_tension, "wire_id", "tension (g)", xdomain_tension, ydomain_tension, {xaxis_type: "linear"});

            labels = plotLayerSelection(data);
            first_call=false;
         }

         var xmin = d3.min(data, function (d) { return d.wireID; });
         var xmax = d3.max(data, function (d) { return d.wireID; });
         makeLine(frame_tension, "tension_limit_sense", [ { x:xmin, y: 45}, {x:xmax, y: 45} ]);
         makeLine(frame_tension, "tension_limit_sense", [ { x:xmin, y: 55}, {x:xmax, y: 55} ]);
         makeLine(frame_tension, "tension_limit_field", [ { x:xmin, y: 72}, {x:xmax, y: 72} ]);
         makeLine(frame_tension, "tension_limit_field", [ { x:xmin, y: 88}, {x:xmax, y: 88} ]);

         //console.log(layerCheckList);
         var data_select = _.filter(data, function(d) {
               //console.log(layerCheckList[d.layerID-1]);
               return layerCheckList[d.layerID-1];
         });
         //console.log("data->");
         //console.log(data);
         //console.log("data_select-> " + data_select.length);
         //console.log(data_select);
         makeScatterPlot(frame_tension, 
            data_select, "wireID", "tens", {
               stroke: function(d) { return (d.tBase==80)?"#3874e3":"#ed5454"; }, 
               fill:   function(d) { return (d.tBase==80)?"#bdd0f4":"#f8d7d7"; },
               stroke_width: function(d) { return (d.tens<d.tBase*0.9 || d.tens>d.tBase*1.1)?"1px":"0px"; }
            }, [
               {label:"sense", stroke:"#ed5454", fill:"#f8d7d7", ypos:"15"},
               {label:"field", stroke:"#3874e3", fill:"#bdd0f4", ypos:"30"}
            ], {label: [ 
                  {data: ["date"] }, 
                  {data: ["layerID", "wireID"], separator: '-'}, 
                  {data: ["tens"], postfix:' g'} ]});
      };

      var svg_tension_hist={};
      var frame_tension_hist={};
      var plotTensionHistogram = function(data, sense_or_field) {

         //console.log("plotTensionHistogram");
         var data_select = _.filter(data, function(d) {
               var is_sense = d.tBase == "50";
               var is_field = d.tBase == "80";
               if (is_sense && sense_or_field!="sense") {
                  //console.log("is_sense " + is_sense + " d.tBase " + d.tBase);
                  return false;
               }
               if (is_field && sense_or_field!="field") return false;
               //console.log(layerCheckList[d.layerID-1]);
               return layerCheckList[d.layerID-1];
         });

         // count entries
         var nx, xmin, xmax, xstep;
         nx = 20;
         if (sense_or_field=="sense") {
            xmin = 40;
            xmax = 60;
         } else {
            xmin = 68;
            xmax = 88;
         }
         xstep = (xmax - xmin)/nx;
         var xdomain = _.range(xmin, xmax, xstep);
         var tick_list = _.range(0, nx, 2);
         var xaxis_tickValues = _.map(tick_list, function(d) { return xdomain[d]; });
         //console.log("xdomain");
         //console.log(xdomain);
         //console.log("xaxis_tickValues");
         //console.log(xaxis_tickValues);

         // test data
         //data = [
         //   {tens:70},
         //   {tens:72},
         //   {tens:78},
         //   {tens:73},
         //   {tens:71},
         //   {tens:70},
         //   {tens:85},
         //   {tens:81}
         //];
         var entries = _.countBy(data_select, function(d) {
               return Math.floor((d.tens - xmin)/xstep);
         });
         var bindatum = _.map(xdomain, function(e, i) { 
               var n = (entries[i])?entries[i]:0;
               return {itens: xdomain[i], ents: n};
         });
         var ydomain = [0, d3.max(bindatum, function(d) { return d.ents;})];
         //console.log("xdomain");
         //console.log(xdomain);
         //console.log("entries");
         //console.log(entries);
         //console.log("bindatum");
         //console.log(bindatum);
         //console.log("ydomain");
         //console.log(ydomain);
         if (first_call_hist[sense_or_field]) {
            d3.select("#menu_tension").append("div").attr("id","menu_tension_"+sense_or_field);
            svg_tension_hist[sense_or_field] = append_svg("#menu_tension_"+sense_or_field);
            first_call_hist[sense_or_field]=false;
         }
         frame_tension_hist[sense_or_field] = make_frame(svg_tension_hist[sense_or_field], "tension (g)", "#/g", xdomain, ydomain, 
            {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues});

         makeBarChart(frame_tension_hist[sense_or_field], bindatum, "itens","ents", 
            function() { return (sense_or_field=="sense")? "#ed5454": "#3874e3"}, 
            {label: [ {data: ["ents"]} ]});

         var tension_mean = _.reduce(data_select, function(memo, d) { return memo + d.tens; }, 0)/data_select.length;
         var tension_rms =  _.reduce(data_select, function(memo, d) { return memo + Math.pow(d.tens-tension_mean,2); }, 0)/data_select.length;
         tension_rms = Math.sqrt(tension_rms);
         var frac_rms = (tension_rms/tension_mean*100).toFixed(0);
         makeStatBox(frame_tension_hist[sense_or_field], w-250, 20, "Mean " + tension_mean.toFixed(2) + ' g');
         makeStatBox(frame_tension_hist[sense_or_field], w-250, 40, "Rms " + tension_rms.toFixed(2) + ' g (' + frac_rms + '%)');
      };


      var plotLoad = function(dailies) {

         var xdomain = d3.extent(dailies, function(d) { return d.utime; });
         var labelA = function(d) { return d.date; };

         // Wire
         var ydomain_wire = [0, dailies[dailies.length-1].wire_tension_kg];
         //console.log(ydomain_wire);
         var svg_wire = append_svg("#menu_load_wire");
         var frame_wire = make_frame(svg_wire, "date", "loading of wires (kg)", xdomain, ydomain_wire, {xaxis_type: "time"});
         makeScatterPlot(frame_wire, dailies, "utime", "wire_tension_kg", { stroke: "#ff1493", fill: "#ff69b4", stroke_width: "1px", line_stroke: "#ff1493" },[],
            { label: [ { data: [ labelA, function(d) { return d.wire_tension_kg.toFixed(1) + ' kg';} ], separator:' '} ]});

         var read_tensionbar_csv = function(csv) {
            var i, j;
            var data=[];
            for (i=0, j=0; i<csv.length; i++) {

               var d1 = csv[i]["Date"];
               var d2 = csv[i]["Tension_kg"];
               //console.log("d1 " + d1);
               //console.log("d2 " + d2);
               if ( _.isEmpty(d1) || _.isEmpty(d2)) continue;

               var utime = Date.parse(d1);
               //console.log("csv " + csv[i] + " Date " + d1 +  " utime " + utime);
               var tension_kg = parseFloat(d2);

               data[j++] = { utime: utime, tension_kg: tension_kg };
            }
            //console.log(data);
            return data;
         };

         //var bar_csv_name ="./csv/tension_bar.csv";

         s3.listObjects(function(err,data) {
               //console.log("=== debug ===");
               if (err=== null) {
                  jQuery.each(data.Contents, function(index, obj) {
                        var params = {Bucket: s3BucketName, Key: obj.Key};
                        var url = s3.getSignedUrl('getObject', params);
                        if (obj.Key!="csv/tension_bar.csv") return true;

                        d3.csv(url, function(error, csv) {
                              var i, j;

                              var bar_data = read_tensionbar_csv(csv);
                              for (i=0, j=0; i<dailies.length; i++) {
                                 dailies[i].bar_tension_kg = bar_data[j].tension_kg;
                                 dailies[i].all_tension_kg = dailies[i].wire_tension_kg + bar_data[j].tension_kg;
                                 if (dailies[i].utime < bar_data[j].utime) {
                                    j++;
                                 }
                              }

                              // TensionBar + Wire
                              var ydomain_all = [d3.min(dailies, function(d) { return d.all_tension_kg; })*0.9, d3.max(dailies, function(d) { return d.all_tension_kg; })*1.1];
                              var svg_all = append_svg("#menu_load_all");
                              var frame_all = make_frame(svg_all, "date", "total loading (kg)", xdomain, ydomain_all, {xaxis_type: "time"});
                              makeScatterPlot(frame_all, dailies, "utime", "all_tension_kg", 
                                 {fill: "#9966ff", stroke: "#6633cc", stroke_width: "1px", line_stroke: "#6633cc" }, [],
                                 { label: [ { data: [ labelA, function(d) { return d.all_tension_kg.toFixed(1) + ' kg';} ], separator:' '} ]});

                              // TensionBar
                              var ydomain_bar = [d3.min(dailies, function(d) { return d.bar_tension_kg; })*0.9, d3.max(dailies, function(d) { return d.bar_tension_kg; })*1.1];
                              //console.log("xdomain_bar " + xdomain_bar);
                              //console.log("ydomain_bar " + ydomain_bar);
                              var svg_bar = append_svg("#menu_load_bar");
                              var frame_bar = make_frame(svg_bar, "date", "loading of tension bars (kg)", xdomain, ydomain_bar, {xaxis_type: "time"});
                              makeScatterPlot(frame_bar, dailies, "utime", "bar_tension_kg", { fill: "#0081B8", stroke: "blue", stroke_width: "1px", line_stroke: "blue"}, [],
                                 { label: [ { data: [ labelA, function(d) { return d.bar_tension_kg.toFixed(1) + ' kg';} ], separator:' '} ]});
                        });
                  });
               }
         });
      };

      var svg_wires = d3.select("#menu_status #status").append("svg").attr({width:w, height:h});
      svg_wires.selectAll("circle")
      .data(holes)
      .enter()
      .append("circle")
      .attr({
            cx: function(d) { return d.x/diam*w*0.9 + w/2; },
            cy: function(d) { return -d.y/diam*h*0.9 + h/2; },
            r: function(d) { return 0.5; },
            fill: "gray"
      });

      var plotLayerDays = function(data) {
         //{"dataID":2,"layerID":37,"wireID":2,"tBase":"80","density":3.359e-09,"date":"2015/06/12","freq":49.89,"tens":78.6}
         var layerData = _.groupBy(data, function(d) {
               return parseInt(d.layerID);
         });
         console.log(layerData);
         var layerNumbers = _.keys(layerData);
         var xmin = _.min(layerNumbers, _.identity);
         var xmax = _.max(layerNumbers, _.identity);
         xmin = parseInt(xmin);
         xmax = parseInt(xmax);
         //console.log("layerNumbers "+ layerNumbers);
         //console.log("xmin "+ xmin);
         //console.log("xmax "+ xmax);
         var mydata = _.range(1,40).map(function(d) {
               return {layerID: d, num_days: 0};
         });
         //console.log(mydata);
         _.each(layerData, function(v, layerID) {
               days = _.groupBy(v, function(d2) {
                     return d2.date;
               });
               //console.log(layerID);
               //console.log(days);
               //console.log(mydata[layerID-1]);
               var num_days = _.keys(days).length;
               //console.log(_.keys(days).length);
               mydata[layerID-1].layerID = layerID;
               mydata[layerID-1].num_days = num_days;
         });
         //console.log(JSON.stringify(mydata));
         var svg = append_svg("#menu_progress #layer_days");
         //console.log("xdomain->");
         //var xdomain = _.range(xmin,xmax+1);
         var xdomain = _.range(0,40);
         //console.log(xmax+1);
         //console.log(xdomain);
         //console.log(mydata);
         var ydomain = [0, 10];
         var xaxis_tickValues = _.range(0,40,5);
         var frame = make_frame(svg, "layer_id", "days", xdomain, ydomain, {xaxis_type: "roundBands", xaxis_tickValues: xaxis_tickValues});
         makeBarChart(frame, mydata, "layerID","num_days", "#A8BE62", {label: [ 
                  {data: ["layerID"], prefix: 'layer_id '},
                  {data: ["num_days"], postfix: ' days'}
         ]});
      };

      //var xml_name = "test.xml";
      //var xml_name = "./xml/COMETCDC.xml";
      //var json_name = "./stats/stats.json";
      //{"date":"2015/05/26","utime":1432566000000,"days":1,"num_sum":11,"num_sense":0,"num_field":11,"num_day":11,"num_ave":11.0,"num_bad":10,"wire_tension_kg":0.9997800000000001,"last_date":"2022/03/31","last_utime":1648652400000}

      s3.listObjects(function(err,data) {
            //console.log("=== debug ===");
            if (err=== null) {
               jQuery.each(data.Contents, function(index, obj) {
                     var params = {Bucket: s3BucketName, Key: obj.Key};
                     var url = s3.getSignedUrl('getObject', params);
                     //console.log("obj.Key " + obj.Key);
                     //console.log("url " + url);
                     if (obj.Key!="stats/stats.json") return true;

                     d3.json(url, function(error, dailies) {

                           //console.log(json);

                           var xdomain =  _.map(dailies, function(d) { return d.days; });
                           var ydomain_sum = [0, d3.max(dailies, function(d) { return d.num_sum; })];
                           var ydomain_day = [0, d3.max(dailies, function(d) { return d.num_day; })];
                           var ydomain_ave = [0, d3.max(dailies, function(d) { return d.num_ave; })];
                           var ydomain_bad = [0, d3.max(dailies, function(d) { return d.num_bad; })];
                           var svg_progress_sum = append_svg("#menu_progress #progress_sum");
                           var svg_progress_day = append_svg("#menu_progress #progress_day");
                           var svg_progress_ave = append_svg("#menu_progress #progress_ave");
                           var svg_progress_bad = append_svg("#menu_progress #bad_wires");

                           var frame_progress_sum = make_frame(svg_progress_sum, "days", "total # of stringed wires",     xdomain, ydomain_sum, {xaxis_type: "roundBands"});
                           var frame_progress_day = make_frame(svg_progress_day, "days", "# of stringed wires",  xdomain, ydomain_day, {xaxis_type: "roundBands"});
                           var frame_progress_ave = make_frame(svg_progress_ave, "days", "ave # of stringed wires",xdomain, ydomain_ave, {xaxis_type: "roundBands"});
                           var frame_progress_bad = make_frame(svg_progress_bad, "days", "# of wires to be re-stringed", xdomain, ydomain_bad, {xaxis_type: "roundBands"});

                           $("#last_day").html("Finished on "+new Date(_.last(dailies).last_utime).toLocaleDateString("ja-JP"));
                           makeBarChart(frame_progress_sum, dailies, "days","num_sum", "#D70071", {label: [ {data: ["num_sum"]} ]});
                           makeBarChart(frame_progress_ave, dailies, "days","num_ave", "#91D48C", {label: [ {data: [function(d) {return d.num_ave.toFixed(1);}]} ]});
                           makeBarChart(frame_progress_day, dailies, "days","num_day", "steelblue", {label: [ {data: ["num_day"]} ]});
                           makeBarChart(frame_progress_bad, dailies, "days","num_bad", "#6521A0", {label: [ {data: ["num_bad"]} ]});

                           plotLoad(dailies);


                           s3.listObjects(function(err,data) {
                                 //console.log("=== debug ===");
                                 if (err=== null) {
                                    jQuery.each(data.Contents, function(index, obj) {
                                          var params = {Bucket: s3BucketName, Key: obj.Key};
                                          var url = s3.getSignedUrl('getObject', params);
                                          if (obj.Key!="daily/current/data.json") return true;

                                          //var json_name = "./daily/current/data.json";
                                          //{"dataID":2,"layerID":37,"wireID":2,"tBase":"80","density":3.359e-09,"date":"2015/06/12","freq":49.89,"tens":78.6}
                                          d3.json(url, function(error, data) {
                                                plotWires(svg_wires, data, dailies[dailies.length-1]);
                                                plotTension(data);
                                                plotTensionHistogram(data,"sense");
                                                plotTensionHistogram(data,"field");
                                                plotLayerDays(data);
                                          });
                                    });
                                 }
                           });
                     });
               });
            }
      });


      var read_gauge_csv = function (csv) {
         var i, j;
         var v1_start;
         var v2_start;
         var v3_start;
         var v4_start;
         var data=[];
         for (i=0, j=0; i<csv.length; i++) {

            var v11 = csv[i]["10deg_1mm"];
            var v12 = csv[i]["10deg_10um"];
            var v21 = csv[i]["90deg_1mm"];
            var v22 = csv[i]["90deg_10um"];
            var v31 = csv[i]["180deg_1mm"];
            var v32 = csv[i]["180deg_10um"];
            var v41 = csv[i]["270deg_1mm"];
            var v42 = csv[i]["270deg_10um"];
            if ( !v11 || !v21 || !v31 || !v41) continue;
            if ( !v12 || !v22 || !v32 || !v42) continue;

            var v1= (parseFloat(v11)+parseFloat(v12))*1000; // mm -> um
            var v2= (parseFloat(v21)+parseFloat(v22))*1000; // mm -> um
            var v3= (parseFloat(v31)+parseFloat(v32))*1000; // mm -> um
            var v4= (parseFloat(v41)+parseFloat(v42))*1000; // mm -> um
            if (j==0) {
               v1_start = v1;
               v2_start = v2;
               v3_start = v3;
               v4_start = v4;
            }

            var d1 = v1 - v1_start;
            var d2 = v2 - v2_start;
            var d3 = v3 - v3_start;
            var d4 = v4 - v4_start;

            var utime = Date.parse(csv[i]["Date"] + ' ' + csv[i]["Time"]);
            //console.log("HOGE utime => " + utime);
            var date = csv[i]["Date"];

            var time = csv[i]["Time"];
            var temp = csv[i]["Temp"];

            data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at10deg",  "disp_um": parseFloat(d1) };
            data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at90deg",  "disp_um": parseFloat(d2) };
            data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at180deg", "disp_um": parseFloat(d3) };
            data[j++] = { "utime": utime, "date":  date, "time":  time, "temp":  temp, "location": "at270deg", "disp_um": parseFloat(d4) };

         }
         //console.log(data);
         return data;
      };

      s3.listObjects(function(err,data) {
            //console.log("=== debug ===");
            if (err=== null) {
               jQuery.each(data.Contents, function(index, obj) {
                     var params = {Bucket: s3BucketName, Key: obj.Key};
                     var url = s3.getSignedUrl('getObject', params);
                     //console.log("obj.Key " + obj.Key);
                     //console.log("url " + url);
                     if (obj.Key!="csv/dial_gauge.csv") return true;

                     d3.csv(url, function(error, csv) {
                           var i, j;

                           var gauge_data = read_gauge_csv(csv);
                           //console.log("csv");
                           //console.log(csv);
                           //console.log("gauge_data");
                           //console.log(gauge_data);
                           //gauge_data = _.take(gauge_data, 1);
                           var xdomain_gauge = d3.extent(gauge_data, function(d) { return d.utime; });
                           var ydomain_gauge = d3.extent(gauge_data, function(d) { return d.disp_um; });
                           //xdomain_gauge = [1432610000000, 1432612000000];
                           //ydomain_gauge = [-10, 10];
                           var svg_gauge = append_svg("#menu_gauge");
                           var frame_gauge = make_frame(svg_gauge, "date", "displacement (um)", xdomain_gauge, ydomain_gauge, {xaxis_type: "time"});
                           var stroke_gauge = {at10deg:"#ed5454", at90deg:"#3874e3", at180deg:"#228b22", at270deg:"#ffa500" };
                           var fill_gauge   = {at10deg:"#f8d7d7", at90deg:"#bdd0f4", at180deg:"#9acd32", at270deg:"#ffead6" };

                           makeScatterPlot(frame_gauge, gauge_data, "utime", "disp_um", 
                              { 
                                 fill: function(d) { return fill_gauge[d.location]; },
                                 stroke: function(d) { return stroke_gauge[d.location]; },
                                 stroke_width: "1px"
                              },
                              [
                                 {label:"10deg",  stroke:'#ed5454', fill: "#f8d7d7", ypos:"66" },
                                 {label:"90deg",  stroke:'#3874e3', fill: "#bdd0f4", ypos:"83" },
                                 {label:"180deg", stroke:'#228b22', fill: "#9acd32", ypos:"100"},
                                 {label:"270deg", stroke:'#ffa500', fill: "#ffead6", ypos:"117"}
                              ],
                              {label: [ {data: [ "date", "time", function(d) {return d.disp_um.toFixed(0);} ], separator:' ', postfix:' um'} ]});
                     });
               });
            }
      });
});
