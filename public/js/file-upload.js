function upload(name, url) {
   $(name + " #progress_bar").show();
   $form = $(name);
   fd = new FormData($form[0]);
   $.ajax(
      {
         url: url,
         type: 'post',
         processData: false,
         contentType: false,
         data: fd,
         dateType: 'json',
         success: function(data) { 
            $(name + " #progress_bar").hide();
            console.log(data); 
         },
         xhr : function(){
            XHR = $.ajaxSettings.xhr();
            if (XHR.upload){
               XHR.upload.addEventListener('progress',function(e) {
                     progre = parseInt(e.loaded/e.total*10000)/100 ;
                        //console.log(progre+"%") ;
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
