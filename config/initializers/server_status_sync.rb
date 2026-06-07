# config/initializers/server_status_sync.rb
Rails.application.config.after_initialize do
  # Don't run in test environment
  unless Rails.env.test?
    # Don't run in console or rake tasks
    if defined?(Rails::Server)
      Rails.logger.info "Synchronizing Factorio server statuses..."
      ServerStatusSyncJob.perform_now
      Rails.logger.info "Factorio server status synchronization completed"
    end
  end
end
