require 'app/models/commit'
require 'app/concerns/git_commit_sha_validator'

require 'peiji_san'

module Pod
  module TrunkApp
    class PodVersion < Sequel::Model
      include Concerns::GitCommitSHAValidator

      DATA_URL = "https://raw.githubusercontent.com/#{ENV['GH_REPO']}/master/%s"

      self.dataset = :pod_versions

      extend PeijiSan
      plugin :timestamps
      plugin :validation_helpers
      plugin :after_initialize

      many_to_one :pod
      one_to_many :commits, :order => Sequel.asc([:updated_at, :created_at])
      one_to_many :log_messages, :order => Sequel.asc([:updated_at, :created_at])

      def after_initialize
        super
        @was_created = new?
      end

      attr_reader :was_created
      alias_method :was_created?, :was_created

      def published?
        commits.any?
      end

      def last_published_by
        commits.last
      end

      def commit_sha
        last_published_by.sha
      end

      def public_attributes
        { 'created_at' => created_at, 'name' => name }
      end

      def destination_path
        File.join('Specs', pod.name, name, "#{pod.name}.podspec.json")
      end

      def data_url
        format(DATA_URL, destination_path)
      end

      def resource_path
        URI.escape("/#{pod.name}/versions/#{name}")
      end

      def description
        "#{pod.name} #{name}"
      end

      def push!(committer, specification_data)
        response = PushJob.new(self, committer, specification_data).push!
        if response.success?
          add_commit(:committer => committer, :sha => response.commit_sha, :specification_data => specification_data)
          pod.add_owner(committer) if pod.owners.empty?
        end
        response
      end

      protected

      UNIQUE_VERSION = [:pod_id, :name]

      def validate
        super
        validates_presence :pod_id
        validates_presence :name

        validates_unique UNIQUE_VERSION
        # Sequel adds the error with the column tuple as the key, but for the
        # user just using `name' as the key is more meaningful.
        if error = errors.delete(UNIQUE_VERSION)
          errors.add(:name, error.first)
        end
      end
    end
  end
end
