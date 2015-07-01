require 'cocoapods-core'
require 'shellwords'
require 'timeout'

module Pod
  module TrunkApp
    class SpecificationWrapper
      def self.from_json(json)
        hash = JSON.parse(json)
        if hash.is_a?(Hash)
          new(Specification.from_hash(hash))
        end
      rescue JSON::ParserError
        # TODO: report error?
        nil
      end

      def initialize(specification)
        @specification = specification
      end

      def name
        @specification.name
      end

      def version
        @specification.version.to_s
      end

      def to_s
        @specification.to_s
      end

      def to_json(*a)
        @specification.to_json(*a)
      end

      def to_pretty_json(*a)
        @specification.to_pretty_json(*a)
      end

      def valid?
        linter.lint
      end

      def validation_errors
        results = {}
        results['warnings'] = remove_prefixes(linter.warnings) unless linter.warnings.empty?
        results['errors']   = remove_prefixes(linter.errors)   unless linter.errors.empty?
        results
      end

      def publicly_accessible?
        return validate_http if @specification.source[:http]
        return validate_git if @specification.source[:git]
        true
      end

      def validate_http
       wrap_timeout Proc.new({ Pod::HTTP.validate_url @specification.source[:http] })
      end

      def validate_git
        wrap_timeout Proc.new({ system('git', 'ls-remote', @specification.source[:git], 'HEAD') })
      end

      private

      def wrap_timeout proc
        begin
          Timeout.timeout(5) do
           return proc.call
          end
        rescue Timeout::Error
          return false
        end
      end

      def linter
        @linter ||= Specification::Linter.new(@specification)
      end

      def remove_prefixes(results)
        results.map do |result|
          result.message.sub(/^\[.+?\]\s*/, '')
        end
      end
    end
  end
end
