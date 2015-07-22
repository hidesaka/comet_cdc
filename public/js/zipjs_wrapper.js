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
                     //$(name + " #progress_msg").html("Compressing...");
                     //$(name + " #progress_bar").attr("value", 0);
                     $(name + " #progress_bar").show();
                  }, function(file) {
                     var li = document.createElement("li");
                     //zipProgress.value = 0;
                     //zipProgress.max = 0;
                     //li.textContent = file.name;
                     //li.appendChild(zipProgress);
                  }, function(current, total) {
                     //zipProgress.value = current;
                     //zipProgress.max = total;
                     var progre = parseInt(current/total*10000)/100 ;
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

