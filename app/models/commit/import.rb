require 'cocoapods-core'
require 'rest'

require 'app/models/commit'
require 'app/models/owner'
require 'app/models/pod'

module Pod
  module TrunkApp
    class Commit
      module Import
        DATA_URL_TEMPLATE = "https://raw.github.com/#{ENV['GH_REPO']}/%s/Specs/%s"

        def self.log_failed_spec_fetch(url)
          LogMessage.create(
            :message => "There was an issue fetching the spec at #{url}",
            :level => :error
          )
          nil
        end

        # TODO: handle network/request failures
        #
        def self.fetch_spec(commit_sha, file)
          url = DATA_URL_TEMPLATE % [commit_sha, file]
          begin
            response = REST.get(url)
            if response.ok?
              data = response.body
              return ::Pod::Specification.from_string(data, file)
            else
              log_failed_spec_fetch(url)
            end
          rescue REST::Error => e
            log_failed_spec_fetch(url)
          end
        end

        # For each changed file, get its data (if it's a podspec).
        #
        def self.import(commit_sha, type, files, committer_email, committer_name)
          files.each do |file|
            next unless file =~ /\.podspec(.json)?\z/

            spec = fetch_spec(commit_sha, file)
            next unless spec

            unless committer = Owner.find_by_email(committer_email)
              committer = Owner.create(:email => committer_email, :name => committer_name)
            end

            pod = Pod.find_or_create(:name => spec.name)
            pod.add_owner(committer) if pod.was_created?

            send(:"handle_#{type}", spec, pod, committer, commit_sha)
          end
        end

        # We add a commit to the pod's version and, if necessary, add a new version.
        #
        def self.handle_modified(spec, pod, committer, commit_sha)
          version = PodVersion.find_or_create(:pod => pod, :name => spec.version.to_s)
          if version.was_created?
            if pod.was_created?
              message = "Pod `#{pod.name}' and version `#{version.name}' created via Github hook."
            else
              message = "Version `#{version.description}' created via Github hook."
            end
            version.add_log_message(
              :reference => "Github hook call to temporary ID: #{object_id}",
              :level => :warning,
              :message => message,
              :owner => committer
            )
          end

          # TODO: add test for returning commit
          version.commits_dataset.first(:sha => commit_sha) || version.add_commit(
            :sha => commit_sha,
            :specification_data => JSON.pretty_generate(spec),
            :committer => committer,
            :imported => true
          )
        end

        # We only check if we have a commit for this pod and version and,
        # if not, add it.
        #
        def self.handle_added(spec, pod, committer, commit_sha)
          version = pod.versions_dataset.first(:name => spec.version.to_s)
          unless version && version.commits_dataset.first(:sha => commit_sha)
            handle_modified(spec, pod, committer, commit_sha)
          end
        end
      end
    end
  end
end
