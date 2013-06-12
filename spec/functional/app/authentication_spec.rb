require File.expand_path('../../../spec_helper', __FILE__)

module Pod::PushApp
  describe "App" do
    def app
      App
    end

    describe "authentication" do
      extend Rack::Test::Methods
      extend SpecHelpers::Response
      extend SpecHelpers::Authentication

      before do
        header 'Content-Type', 'text/yaml'
      end

      it "allows access with a valid session belonging to an owner" do
        session = create_session_with_owner
        get '/me', nil, { 'Authorization' => "Token #{session.token}"}
        last_response.status.should == 200
      end

      it "does not allow access when no authentication token is supplied" do
        get '/me'
        last_response.status.should == 401
        yaml_response.should == "Please supply an authentication token."
      end

      it "does not allow access when an invalid authentication token is supplied" do
        get '/me', nil, { 'Authorization' => 'Token invalid' }
        last_response.status.should == 401
        yaml_response.should == "Authentication token is invalid."
      end
    end
  end
end
