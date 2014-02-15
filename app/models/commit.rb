require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

module Pod
  module TrunkApp
    class Commit < Sequel::Model
      include Concerns::GitCommitSHAValidator

      self.dataset = :commits

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :committer, :class => 'Pod::TrunkApp::Owner'
      many_to_one :pod_version
      one_to_many :push_jobs, :order => Sequel.desc(:updated_at)

      alias_method :pushed?, :pushed

      def self.succeeded
        where(:pushed => true).all
      end

      def self.failed
        where(:pushed => false).all
      end

      def self.in_progress
        where(:pushed => nil).all
      end

      def pushed_by
        push_jobs.last
      end

      def in_progress?
        succeeded.nil?
      end

      # All state is tied to the pushed state.
      #  * nil: In progress.
      #  * true: Successfully pushed.
      #  * false: Unsuccessfully pushed.
      #
      def succeeded
        pushed
      end

      protected

      def validate
        super
        validates_presence :committer_id
        validates_presence :pod_version_id
        validates_presence :specification_data
        validates_git_commit_sha :sha
      end
    end
  end
end

