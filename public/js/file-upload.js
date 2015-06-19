function upload(form) {
alert("start uploading");
   $form = $('#upload-form');
   fd = new FormData($form[0]);
   $.ajax(
      {
         url: '/xml_upload',
         type: 'post',
         processData: false,
         contentType: false,
         data: fd,
         success: function() { console.log("sucess"); },
         xhr : function(){
            XHR = $.ajaxSettings.xhr();
            if (XHR.upload){
               XHR.upload.addEventListener('progress',function(e) {
                     progre = parseInt(e.loaded/e.total*10000)/100 ;
                        console.log(progre+"%") ;
                        $("#progress_bar").width(parseInt(progre/100*300*100)/100+"px");
                           $("#progress_bar").height("30px");
                           $("#progress_bar").html(progre+"%");
                     }, false); 
                  }
                  return XHR;
               },
   });
   return false;
}
