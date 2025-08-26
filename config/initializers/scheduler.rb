Rails.application.config.after_initialize do
  # Simple in-process scheduler to run expiry every 30 seconds in dev/test.
  # In production, use a proper scheduler (cron/sidekiq-scheduler/etc.).
  if Rails.env.development? || Rails.env.test?
    Thread.new do
      loop do
        begin
          HoldExpiryJob.perform_now
        rescue => e
          Rails.logger.error("HoldExpiryJob error: #{e.message}")
        ensure
          sleep 30
        end
      end
    end
  end
end

