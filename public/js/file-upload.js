function upload(name, file, url) {
   $form = $(name);
   fd = new FormData($form);
   var file_name = $(file).prop('files')[0].name;
   console.log("csv file name -> ", file_name);
   var accept_files = /tension_bar\.csv|dial_gauge\.csv|outside_\d{8}\.csv|inside_\d{8}\.csv/;
   if (!accept_files.exec(file_name)) {
      $(name + " #error").html("Select csv file")
      $(name + " #error").css('color','#ff0000');
      $(name + " #error").css('font-weight','Bold');
      $(name + " #error").show();
      console.log("unknown file name -> not uploaded.");
      return false;
   } else {
      console.log("uploading..");
   }
   $(name + " #error").html("")
   $(name + " #error").hide();
   $(name + " #progress_msg").html("");
   $(name + " #progress_bar").attr("value", 0);
   $(name + " #progress_bar").show();

   $.ajax(
      {
         url: url,
         type: 'post',
         processData: false,
         contentType: false,
         data: fd,
         dateType: 'json',
         success: function(data) { 
            console.log("succeeded to upload csv"); 
            $(name + " #upload-form-file").val("").removeAttr("disabled")
            $(name + " #progress_msg").html("done!").fadeOut(3000)
            $(name + " #progress_bar").fadeOut(3000)
         },
         xhr : function(){
            XHR = $.ajaxSettings.xhr();
            if (XHR.upload){
               XHR.upload.addEventListener('progress',function(e) {
                     progre = parseInt(e.loaded/e.total*10000)/100 ;
                        //console.log(progre+"%") ;
                        $(name + " #progress_msg").show();
                        $(name + " #progress_msg").height("30px");
                        $(name + " #progress_msg").html(progre+"%");
                        $(name + " #progress_bar").attr("value", progre);
                  }, false); 
               }
               return XHR;
            },
      });
      return false;
   }
