require 'rails/generators/base'
require 'rails/generators/active_record'

module TestTrack
  module Generators
    class InstallSplitRegistryCacheGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      desc "Creates a migration to add the test_track_split_registry_cache table."

      source_root File.expand_path('templates', __dir__)

      def create_migration_file
        migration_template(
          'create_test_track_split_registry_cache.rb.erb',
          'db/migrate/create_test_track_split_registry_cache.rb'
        )
      end
    end
  end
end
