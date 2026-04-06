require 'rails_helper'

RSpec.describe TestTrack::SplitRegistryCache do
  let(:registry_hash) do
    {
      'splits' => {
        'time' => {
          'weights' => { 'back_in_time' => 100, 'power_of_love' => 0 },
          'feature_gate' => false
        }
      },
      'experience_sampling_weight' => 1
    }
  end

  describe '.fetch_registry' do
    context 'when no record exists' do
      it 'returns nil' do
        expect(described_class.fetch_registry).to be_nil
      end
    end

    context 'when a record exists' do
      before { described_class.store_registry(registry_hash) }

      it 'returns the deserialized registry hash' do
        expect(described_class.fetch_registry).to eq(registry_hash)
      end
    end
  end

  describe '.store_registry' do
    it 'persists a new registry record' do
      expect { described_class.store_registry(registry_hash) }
        .to change { described_class.count }.from(0).to(1)
    end

    it 'overwrites an existing registry record rather than creating a second row' do
      described_class.store_registry(registry_hash)

      updated = registry_hash.merge('experience_sampling_weight' => 5)
      expect { described_class.store_registry(updated) }
        .not_to change { described_class.count }

      expect(described_class.fetch_registry).to eq(updated)
    end

    it 'stores the registry as JSON' do
      described_class.store_registry(registry_hash)
      raw = described_class.find(described_class::SINGLETON_ID).registry_json
      expect(JSON.parse(raw)).to eq(registry_hash)
    end
  end
end
