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
         dateType: 'json',
         success: function(data) { console.log(data); },
         xhr : function(){
            XHR = $.ajaxSettings.xhr();
            if (XHR.upload){
               XHR.upload.addEventListener('progress',function(e) {
                     progre = parseInt(e.loaded/e.total*10000)/100 ;
                        console.log(progre+"%") ;
                           $("#progress_msg").height("30px");
                           $("#progress_msg").html(progre+"%");
                           $("#progress_bar").attr("value", progre);
                     }, false); 
                  }
                  return XHR;
               },
   });
   return false;
}
