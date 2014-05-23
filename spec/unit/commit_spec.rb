require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/commit'

module Pod::TrunkApp
  describe Commit do
    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = @pod.add_version(:name => '1.2.0')
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @commit = Commit.new(
        :pod_version => @version,
        :committer => @owner,
        :sha => '3ca23060197547eef92983f15590b5a87270615f',
        :specification_data => fixture_read('AFNetworking.podspec')
      )
    end

    describe 'in general' do
      it 'marks it as not being imported' do
        @commit.save(:raise_on_save_failure => true)
        @commit.reload.should.not.be.imported
      end

      it 'returns a URL from where the spec data can be retrieved' do
        expected = 'https://raw.githubusercontent.com/CocoaPods/Specs/' \
          "3ca23060197547eef92983f15590b5a87270615f/#{@version.destination_path}"
        @commit.data_url.should == expected
      end
    end

    describe 'concerning validations' do
      it 'needs a pod version' do
        @commit.should.not.validate_with(:pod_version_id, nil)
        @commit.should.validate_with(:pod_version_id, @version.id)
      end

      it 'needs specification data' do
        @commit.should.not.validate_with(:specification_data, nil)
        @commit.should.not.validate_with(:specification_data, '')
        @commit.should.not.validate_with(:specification_data, ' ')
        @commit.should.validate_with(:specification_data, fixture_read('AFNetworking.podspec'))
      end

      it 'needs a valid commit sha' do
        @commit.should.not.validate_with(:sha, '')
        @commit.should.not.validate_with(:sha, '3ca23060')
        @commit.should.not.validate_with(:sha, 'g' * 40) # hex only
        @commit.should.not.validate_with(:sha, nil)
        @commit.should.validate_with(:sha, '3ca23060197547eef92983f15590b5a87270615f')
      end

      it 'needs a committer' do
        @commit.should.not.validate_with(:committer_id, nil)
        @commit.should.validate_with(:committer_id, @owner.id)
      end

      describe 'at the DB level' do
        it "raises if an empty `pod_version_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.pod_version_id = nil
            @commit.save(:validate => false)
          end
        end

        it "raises if an empty `committer_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.committer_id = nil
            @commit.save(:validate => false)
          end
        end

        it "raises if an empty `specification_data' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.specification_data = nil
            @commit.save(:validate => false)
          end
        end

        it "raises if an empty `sha' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.sha = nil
            @commit.save(:validate => false)
          end
        end

        it "raises if a duplicate `pod_version_id + sha' gets inserted" do
          Commit.create(
            :pod_version => @version,
            :committer => @owner,
            :sha => '3ca23060197547eef92983f15590b5a87270615f',
            :specification_data => fixture_read('AFNetworking.podspec')
          )
          should.raise Sequel::UniqueConstraintViolation do
            @commit.save(:validate => false)
          end
        end
      end
    end

    describe 'concerning webhooks' do
      it 'sends off a Webhook message' do
        Webhook.urls = []

        sha = '7f694a5c1e43543a803b5d20d8892512aae375f3'
        version = '1.0.0'

        @pod = Pod.create(:name => 'Webhook')
        @version = PodVersion.create(:pod => @pod, :name => version)
        @committer = Owner.create(:email => 'appie-webhook@example.com', :name => 'Appie Duran')

        Webhook.expects(:call).once.with do |parameter|
          parameter.should.match(/"type":"commit"/)
          parameter.should.match(/"created_at":/)
          expected = 'https://raw.githubusercontent.com/CocoaPods/Specs/' \
            '7f694a5c1e43543a803b5d20d8892512aae375f3/Specs/Webhook/' \
            '1.0.0/Webhook.podspec.json'
          parameter.should.match(/"data_url":"#{expected}"/)
        end

        Commit.send :alias_method, :after_save, :after_commit
        @version.add_commit(:committer => @committer, :sha => sha, :specification_data => 'DATA')
        Commit.send :remove_method, :after_save
      end
    end

  end
end
