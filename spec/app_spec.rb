require 'spec_helper'
require 'pp'


#     it "status code is 200" do
#        authorize 'comet', 'mu_e_conv'
#        get '/'
#        pp last_response.status
#        #visit '/'
#        #pp page.body
#        #pp response_headers
#        #expect(last_response).to be_ok
#        #visit '/'
#     end
#
describe "Body" do

   before :all do 
      get '/'
   end

   describe "Shift Calendar" do
      it "contains a link" { }
      it "contains a google calendar" {}
   end

   describe "Status" do
      it "contains a svg" {}
   end

   describe "Progress" do
      it "contains a finished day message" {}
      it "contains five svgs" {}
   end

   describe "Tension" do
      it "contains three svgs" {}
   end

   describe "Endplate" do
      it "contains six svgs" {}
   end

   describe "Files" do
      describe "Check sheets" do
         it "contains a link" { }
         it "contains a link" { }
      end
      describe "Catalogs" do
         it "contains a link" { }
         it "contains a non-link" { }
         it "contains a link" { }
         it "contains a link" { }
         it "contains a link" { }
      end
      describe "Data" do
         it "contains a link" { }
         it "contains a link" { }
         it "contains a link" { }
         it "contains a link" { }
         it "contains a link" { }
         it "contains a link" { }
      end
   end

   describe "Upload" do
      it "contains a form" { }
      it "contains a form" { }
   end
end
