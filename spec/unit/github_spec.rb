require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  class GitHub
    public :url_for
  end

  describe "GitHub" do
    def fixture_response(name)
      YAML.unsafe_load(fixture_read("GitHub/#{name}.yaml"))
    end

    before do
      @auth = { :username => 'alloy', :password => 'secret' }
      @github = GitHub.new('CocoaPods/Specs', 'master', @auth)
      REST.stubs(:get).with(@github.url_for('git/refs/heads/master'), GitHub::HEADERS, @auth).returns(fixture_response('sha_latest_commit'))
      REST.stubs(:get).with(@github.url_for('git/commits/632671a3f28771a3631119354731dba03963a276'), GitHub::HEADERS, @auth).returns(fixture_response('sha_base_tree'))
    end

    it "returns a URL for a given API path" do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it "returns the SHA of the latest commit on the `master` branch" do
      @github.fetch_latest_commit_sha.should == '632671a3f28771a3631119354731dba03963a276'
    end

    it "returns the SHA of the tree of the latest commit and caches it" do
      commit_sha = '632671a3f28771a3631119354731dba03963a276'
      @github.fetch_base_tree_sha(commit_sha).should == 'f93e3a1a1525fb5b91020da86e44810c87a2d7bc'
    end

    before do
      body = {
        :base_tree => 'f93e3a1a1525fb5b91020da86e44810c87a2d7bc',
        :tree => [{
          :encoding => 'utf-8',
          :mode     => '100644',
          :path     => 'AFNetworking/1.2.0/AFNetworking.podspec',
          :content  => fixture_read('AFNetworking.podspec')
        }]
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/trees'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_tree'))
    end

    it "creates a new tree object, which represents the contents, and returns its SHA" do
      base_tree_sha = 'f93e3a1a1525fb5b91020da86e44810c87a2d7bc'
      path, content = 'AFNetworking/1.2.0/AFNetworking.podspec', fixture_read('AFNetworking.podspec')
      @github.create_new_tree(base_tree_sha, path, content).should == '18f8a32cdf45f0f627749e2be25229f5026f93ac'
    end

    before do
      body = {
        :parents => ['632671a3f28771a3631119354731dba03963a276'],
        :tree    => '18f8a32cdf45f0f627749e2be25229f5026f93ac',
        :message => '[Add] AFNetworking 1.2.0'
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/commits'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_commit'))
    end

    it "creates a new commit object for the new tree object" do
      new_tree_sha = '18f8a32cdf45f0f627749e2be25229f5026f93ac'
      base_commit_sha = '632671a3f28771a3631119354731dba03963a276'
      message = '[Add] AFNetworking 1.2.0'
      @github.create_new_commit(new_tree_sha, base_commit_sha, message).should == '4ebf6619c831963fafb7ccd8e9aa3079f00ac41d'
    end

    before do
      body = {
        :ref => 'refs/heads/AFNetworking-1.2.0',
        :sha => '4ebf6619c831963fafb7ccd8e9aa3079f00ac41d'
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/refs'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_branch'))
    end

    it "creates a new branch object with a new commit object" do
      commit_sha = '4ebf6619c831963fafb7ccd8e9aa3079f00ac41d'
      @github.create_new_branch('AFNetworking-1.2.0', commit_sha).should == 'refs/heads/AFNetworking-1.2.0'
    end

    before do
      body = {
        :title => '[Add] AFNetworking 1.2.0',
        :body  => 'Specification for AFNetworking 1.2.0',
        :head  => 'refs/heads/AFNetworking-1.2.0',
        :base  => 'refs/heads/master'
      }.to_json
      REST.stubs(:post).with(@github.url_for('pulls'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_pull-request'))
    end

    it "creates a new pull-request for a branch and returns the pull/issue number" do
      branch_ref = 'refs/heads/AFNetworking-1.2.0'
      @github.create_new_pull_request('[Add] AFNetworking 1.2.0', 'Specification for AFNetworking 1.2.0', branch_ref).should == 3
    end
  end
end
