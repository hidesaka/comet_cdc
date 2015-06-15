$("#file-xml").fileinput({
   mainClass: "input_group",
   showPreview: false,
   showCaption: true,
   allowedFileExtensions: ["xml"],
   msgValidationError: "Select xml file",
   /*
   layoutTemplates: {
      main1: "<div class=\'input-group {class}\'>\n" +
         "   <div class=\'input-group-btn\'>\n" +
         "       {browse}\n" +
         "       {upload}\n" +
         "   </div>\n" +
         "   {caption}\n" +
         "</div>",
      progress: '<div class="progress">\n' +
                  '    <div class="progress-bar progress-bar-success progress-bar-striped text-center" role="progressbar" aria-valuenow="{percent}" aria-valuemin="0" aria-valuemax="100" style="width:{percent}%;">\n' +
                  '        {percent}%\n' +
                  '     </div>\n' +
                  '</div>'

   }
   */
});
