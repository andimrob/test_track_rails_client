class TestTrack::Remote::SplitRegistry
  include TestTrack::RemoteModel

  collection_path 'api/v3/builds/:build_timestamp/split_registry'

  class << self
    def fake_instance_attributes(_)
      ::TestTrack::Fake::SplitRegistry.instance.to_h
    end

    def instance
      # TODO: FakeableHer needs to make this faking a feature of `get`
      if faked?
        new(fake_instance_attributes(nil))
      else
        get("api/v3/builds/#{TestTrack.build_timestamp}/split_registry")
      end
    end

    # Triggers an immediate synchronous refresh from the TestTrack API and
    # updates both the in-process cache and the database backing store.
    # Called by ConfigUpdater after split configuration changes.
    def reset
      TestTrack::SplitRegistryUpdater.refresh_now!
    end

    def to_hash
      if faked?
        instance.attributes.freeze
      else
        TestTrack::SplitRegistryUpdater.registry
      end
    end
  end
end
