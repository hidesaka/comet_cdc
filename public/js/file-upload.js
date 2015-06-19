function showProgress(evt) {
   if (evt.lengthComputable) {
      var percentComplete = (evt.loaded / evt.total) * 100;
      $('#progressbar-xml').progressbar("option", "value", percentComplete );
   }  
}
$('#xml_upload').submit(function() {
      var fd = new FormData($('#xml_upload').get(0));
      $.ajax({
            url: "/xml_upload",
            type: "POST",
            data: fd,
            processData: false,
            contentType: false,
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
      .done(function( data ) {
            $('#result').text(data.width + "x" + data.height);
      });
      return false;
});
