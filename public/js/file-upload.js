function showProgress(evt) {
   if (evt.lengthComputable) {
      var percentComplete = (evt.loaded / evt.total) * 100;
      $('#progressbar-xml').progressbar("option", "value", percentComplete );
   }  
}

$("#xml_upload").on("change", 'input[type="file"]', function(e) {
      e.preventDefault();
      var formData = new FormData();
      var files = this.files;
      $.each(files, function(i, file){
            formData.append('file', file);
      });
      $.ajax({
            url: '/xml_upload',
            type: 'post',
            data: formData,
            processData: false,
            contentType: false,
            dataType: 'html',
            complete: function(){},
            success: function(res) {}
            xhr: function() {
               myXhr = $.ajaxSettings.xhr();
               if (myXhr.upload){
                  myXhr.upload.addEventListener('progress',showProgress, false);
               } else {
                  console.log("Uploadress is not supported.");
               }
               return myXhr;
            }
      })
});
