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
         success: function() {
            console.log("sucess");
         }
   });
   return false;
}
