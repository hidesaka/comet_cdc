Zip.inflate_file("example.zip", function (zip) {
      console.log(zip.files["COMETCDC.xml"]);
});
