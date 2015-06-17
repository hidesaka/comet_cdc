$(function() {
      var awsRegion = "us-east-1";
      var cognitoParams = {
         //IdentityPoolId: "us-east-1:03c415f9-4328-419d-bade-f099e836ef6a"
         //IdentityPoolId: "us-east-1:03c415f9-4328-419d-bade-f099e836ef6a"
         IdentityPoolId: "us-east-1:435dfdc9-d483-4f5e-8f8b-27e3569ad9af"
      };

      AWS.config.region = awsRegion;
      AWS.config.credentials = new AWS.CognitoIdentityCredentials(cognitoParams);
      AWS.config.credentials.get(function(err) {
            if (!err) {
               console.log("Cognito Identity Id: " + AWS.config.credentials.identityId);
            }
      });

      var s3BucketName = "comet-cdc";
      var s3RegionName = "ap-northeast-1"
      var s3 = new AWS.S3({params: {Bucket: s3BucketName, Region: s3RegionName}});
      var params = {Bucket: s3BucketName, Key: 'csv/dial_gauge.csv'};
      s3.getObject(params, function(err,data) {
            if (err) {
               console.log("error!!");
            } else {
               console.log(data);
            }
      });
      /*
       s3.listObjects(function(err,data) {
             if (err=== null) {
                jQuery.each(data.Contents, function(index, obj) {
                      var params = {Bucket: s3BucketName, Key: obj.Key};
                      var url = s3.getSignedUrl('getObject', params);
                      console.log("obj.Key " + obj.Key);
                      console.log("url " + url);
                });
             }
       });
       */

});
