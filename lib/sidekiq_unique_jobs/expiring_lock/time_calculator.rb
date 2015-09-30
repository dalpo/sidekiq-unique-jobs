module SidekiqUniqueJobs
  class ExpiringLock
    class TimeCalculator
      def self.for_item(item)
        new(item)
      end

      def initialize(item)
        @item = item
      end

      def seconds
        time_until_scheduled + unique_job_expiration
      end

      def time_until_scheduled
        scheduled = item['at'.freeze]
        return 0 unless scheduled
        (Time.at(scheduled) - Time.now.utc).to_i
      end

      def unique_job_expiration
        @unique_job_expiration ||=
          (
            worker_class_unique_job_expiration ||
            SidekiqUniqueJobs.config.default_expiration
          ).to_i
      end

      def worker_class_unique_job_expiration
        return unless worker_class.respond_to?(:get_sidekiq_options)
        worker_class.get_sidekiq_options['unique_job_expiration'.freeze]
      end

      def worker_class
        @worker_class ||= SidekiqUniqueJobs.worker_class_constantize(item['class'.freeze])
      end

      private

      attr_reader :item
    end
  end
end
