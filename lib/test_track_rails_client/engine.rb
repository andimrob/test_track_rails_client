require 'active_job'
require 'active_model'
require 'active_record'
require 'test_track'
require 'test_track/split_registry_updater'

module TestTrackRailsClient
  class Engine < ::Rails::Engine
    isolate_namespace TestTrack

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer after: 'active_support.initialize_time_zone' do
      TestTrack.set_build_timestamp! unless ENV['SKIP_TESTTRACK_SET_BUILD_TIMESTAMP'] == '1'
    end

    config.after_initialize do
      TestTrack::SplitRegistryUpdater.start! if TestTrack.enabled?
    end
  end
end
