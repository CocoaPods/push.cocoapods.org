require 'app/models/submission_job'

module Pod
  module PushApp
    class LogMessage < Sequel::Model
      self.dataset = :log_messages
      plugin :timestamps

      many_to_one :submission_job
    end
  end
end
