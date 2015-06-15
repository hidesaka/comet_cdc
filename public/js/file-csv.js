$("#file-csv").fileinput({
   mainClass: "input_group",
   showPreview: false,
   showCaption: true,
   allowedFileExtensions: ["csv"],
   msgValidationError: "Select csv file",
   /*
   layoutTemplates: {
      main1: "<div class=\'input-group {class}\'>\n" +
         "   <div class=\'input-group-btn\'>\n" +
         "       {browse}\n" +
         "       {upload}\n" +
         "   </div>\n" +
         "   {caption}\n" +
         "</div>"
   }
   */
});
