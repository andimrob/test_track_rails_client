module TestTrack
  # Manages a single background thread per process that periodically fetches
  # the split registry from the TestTrack API and persists it to the database.
  # All application threads read the registry from an in-memory cache that this
  # updater maintains, eliminating per-request database or cache-store writes.
  class SplitRegistryUpdater
    MUTEX = Mutex.new
    private_constant :MUTEX

    class << self
      # Starts the background updater thread. Safe to call multiple times —
      # no-ops if the thread is already alive.
      def start!
        return if @thread&.alive?

        pre_warm_from_db
        @thread = Thread.new { run_loop }
        @thread.name = 'TestTrack::SplitRegistryUpdater'
        @thread.abort_on_exception = false
      end

      # Returns the current in-memory split registry hash, or nil if not yet loaded.
      def registry
        MUTEX.synchronize { @registry }
      end

      # Performs an immediate synchronous refresh from the TestTrack API.
      # Used by ConfigUpdater after split configuration changes so that the
      # next call to registry returns fresh data.
      def refresh_now!
        do_refresh
      end

      # Resets in-process state. Intended for use in tests.
      def reset_for_testing!
        if @thread&.alive?
          @thread.kill
          @thread.join
        end
        MUTEX.synchronize { @registry = nil }
        @thread = nil
      end

      private

      def pre_warm_from_db
        stored = TestTrack::SplitRegistryCache.fetch_registry
        MUTEX.synchronize { @registry = stored.freeze } if stored
      rescue => e
        Rails.logger.error "TestTrack::SplitRegistryUpdater failed to pre-warm from DB: #{e}"
      end

      def run_loop
        loop do
          sleep TestTrack.split_registry_refresh_interval
          do_refresh
        end
      end

      def do_refresh
        attrs = fetch_from_api
        if attrs
          persist_to_db(attrs)
          MUTEX.synchronize { @registry = attrs.freeze }
        end
      rescue => e
        Rails.logger.error "TestTrack::SplitRegistryUpdater failed to refresh: #{e}"
      end

      def fetch_from_api
        TestTrack::Remote::SplitRegistry.instance.attributes
      rescue *TestTrack::SERVER_ERRORS => e
        Rails.logger.error "TestTrack failed to fetch split registry from API: #{e}"
        nil
      end

      def persist_to_db(registry_hash)
        TestTrack::SplitRegistryCache.store_registry(registry_hash)
      rescue => e
        Rails.logger.error "TestTrack::SplitRegistryUpdater failed to persist split registry: #{e}"
      end
    end
  end
end
