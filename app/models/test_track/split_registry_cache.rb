class TestTrack::SplitRegistryCache < ActiveRecord::Base
  self.table_name = 'test_track_split_registry_cache'

  SINGLETON_ID = 1
  private_constant :SINGLETON_ID

  class << self
    def fetch_registry
      record = find_by(id: SINGLETON_ID)
      JSON.parse(record.registry_json) if record
    end

    def store_registry(registry_hash)
      upsert(
        { id: SINGLETON_ID, registry_json: registry_hash.to_json, updated_at: Time.current, created_at: Time.current },
        unique_by: :id
      )
    end
  end
end
