(function(obj) {

      var requestFileSystem = obj.webkitRequestFileSystem || obj.mozRequestFileSystem || obj.requestFileSystem;

      function onerror(message) {
         alert(message);
      }

      function createTempFile(callback) {
         var tmpFilename = "tmp.zip";
         requestFileSystem(TEMPORARY, 4 * 1024 * 1024 * 1024, function(filesystem) {
               function create() {
                  filesystem.root.getFile(tmpFilename, {
                        create : true
                     }, function(zipFile) {
                        callback(zipFile);
                  });
               }

               filesystem.root.getFile(tmpFilename, null, function(entry) {
                     entry.remove(create, create);
               }, create);
         });
      }

      var model = (function() {
            var zipFileEntry, zipWriter, writer, creationMethod, URL = obj.webkitURL || obj.mozURL || obj.URL;

            return {
               setCreationMethod : function(method) {
                  creationMethod = method;
               },
               addFiles : function addFiles(files, oninit, onadd, onprogress, onend) {
                  var addIndex = 0;

                  function nextFile() {
                     var file = files[addIndex];
                     onadd(file);
                     zipWriter.add(file.name, new zip.BlobReader(file), function() {
                           addIndex++;
                           if (addIndex < files.length)
                              nextFile();
                           else
                              onend();
                     }, onprogress);
                  }

                  function createZipWriter() {
                     zip.createWriter(writer, function(writer) {
                           zipWriter = writer;
                           oninit();
                           nextFile();
                     }, onerror);
                  }

                  if (zipWriter)
                     nextFile();
                  else if (creationMethod == "Blob") {
                     writer = new zip.BlobWriter();
                     createZipWriter();
                  } else {
                     createTempFile(function(fileEntry) {
                           zipFileEntry = fileEntry;
                           writer = new zip.FileWriter(zipFileEntry);
                           createZipWriter();
                     });
                  }
               },
               getBlobURL : function(callback) {
                  zipWriter.close(function(blob) {
                        var blobURL = creationMethod == "Blob" ? URL.createObjectURL(blob) : zipFileEntry.toURL();
                        callback(blobURL);
                        zipWriter = null;
                  });
               },
               getBlob : function(callback) {
                  zipWriter.close(callback);
               }
            };
      })();

      obj.zipWrapper = function(id, callback) {
         var fileInput = $(id)[0];
         console.log("fileInput " + fileInput);

         model.setCreationMethod("Blob");

         fileInput.addEventListener('change', function(event) {
               model.addFiles(fileInput.files, function() {
                     var name = "#upload-xml";
                     $(name + " #progress_msg").html("Compressing...");
                     $(name + " #progress_bar").attr("value", 0);
                     $(name + " #progress_bar").show();
                  }, function(file) {
                     //var li = document.createElement("li");
                     //zipProgress.value = 0;
                     //zipProgress.max = 0;
                     //li.textContent = file.name;
                     //li.appendChild(zipProgress);
                  }, function(current, total) {
                     //zipProgress.value = current;
                     //zipProgress.max = total;
                     var progre = parseInt(current/total*10000)/100 ;
                     var name = "#upload-xml";
                     $(name + " #progress_msg").height("30px");
                     $(name + " #progress_msg").html("Compressing.. " + progre+"%");
                     $(name + " #progress_bar").attr("value", progre);
                  }, function() {
                     //if (zipProgress.parentNode)
                     //   zipProgress.parentNode.removeChild(zipProgress);

                     console.log("finish to make zipFile");

                     model.getBlob(function(blob) {
                           callback(blob);
                     });

                     //fileInput.value = "";
                     //fileInput.disabled = false;
               });
         });
      }

})(this);

$(function() {
      zipWrapper("#upload-xml #upload-form-file", function(blob) {
            var name = "#upload-xml";
            var url = "/zip_upload";
            $(name + " #progress_msg").show();
            $(name + " #progress_bar").attr("value", 0);
            $(name + " #progress_bar").show();
            $(name + " #upload-form-file").attr("disabled","disabled");
            console.log("starting ajax...");
            console.log("blog: " + blob)
            var fd = new FormData();
            fd.append("zip", blob);
            $.ajax({
                  url: url,
                  type: 'post',
                  processData: false,
                  contentType: false,
                  data: fd,
                  error: function (xhr, textStatus, errorThrown) {
                     console.log("there is error at ajax...");
                     console.log(xhr.responseText);
                  },
                  success: function(data) { 
                     $(name + " #upload-form-file").val("").removeAttr("disabled");
                     $(name + " #progress_msg").html("done!").fadeOut(3000);
                     $(name + " #progress_bar").fadeOut(3000);
                     console.log(data); 
                  },
                  xhr : function() {
                     XHR = $.ajaxSettings.xhr();
                     if (XHR.upload){
                        XHR.upload.addEventListener('progress',function(e) {
                              progre = parseInt(e.loaded/e.total*10000)/100 ;
                                 //console.log(progre+"%") ;
                                 $(name + " #progress_msg").height("30px");
                                 $(name + " #progress_msg").html("Uploading.. " + progre+"%");
                                 $(name + " #progress_bar").attr("value", progre);
                           }, false); 
                        }
                        return XHR;
                     },
               });
         });
   });
