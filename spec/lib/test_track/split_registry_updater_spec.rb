require 'rails_helper'

RSpec.describe TestTrack::SplitRegistryUpdater do
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

  before do
    described_class.reset_for_testing!
    allow(TestTrack::SplitRegistryCache).to receive(:fetch_registry).and_return(nil)
    allow(TestTrack::SplitRegistryCache).to receive(:store_registry)
  end

  after { described_class.reset_for_testing! }

  describe '.registry' do
    it 'returns nil when no refresh has occurred' do
      expect(described_class.registry).to be_nil
    end

    context 'after a successful refresh' do
      before do
        allow(TestTrack::Remote::SplitRegistry).to receive(:instance)
          .and_return(double(attributes: registry_hash))
        described_class.refresh_now!
      end

      it 'returns the fetched registry' do
        expect(described_class.registry).to eq(registry_hash)
      end

      it 'returns a frozen hash' do
        expect(described_class.registry).to be_frozen
      end
    end
  end

  describe '.refresh_now!' do
    context 'when the API responds successfully' do
      before do
        allow(TestTrack::Remote::SplitRegistry).to receive(:instance)
          .and_return(double(attributes: registry_hash))
      end

      it 'updates the in-memory registry' do
        expect { described_class.refresh_now! }
          .to change { described_class.registry }.from(nil).to(registry_hash)
      end

      it 'persists the registry to the database' do
        described_class.refresh_now!
        expect(TestTrack::SplitRegistryCache).to have_received(:store_registry).with(registry_hash)
      end
    end

    context 'when the API raises a server error' do
      before do
        allow(TestTrack::Remote::SplitRegistry).to receive(:instance)
          .and_raise(Faraday::TimeoutError, 'too slow!')
        allow(Rails.logger).to receive(:error)
      end

      it 'does not raise' do
        expect { described_class.refresh_now! }.not_to raise_error
      end

      it 'logs the error' do
        described_class.refresh_now!
        expect(Rails.logger).to have_received(:error).with(/failed to fetch split registry from API/)
      end

      it 'leaves the registry unchanged' do
        expect { described_class.refresh_now! }.not_to change { described_class.registry }
      end
    end

    context 'when the API raises a Her remote server error' do
      before do
        allow(TestTrack::Remote::SplitRegistry).to receive(:instance)
          .and_raise(Her::Errors::RemoteServerError, '503')
        allow(Rails.logger).to receive(:error)
      end

      it 'does not raise' do
        expect { described_class.refresh_now! }.not_to raise_error
      end
    end
  end

  describe '.start!' do
    context 'when pre-warm data exists in the database' do
      before do
        allow(TestTrack::SplitRegistryCache).to receive(:fetch_registry).and_return(registry_hash)
        # Prevent the background thread from doing anything during the test
        allow(described_class).to receive(:run_loop)
      end

      it 'pre-warms the in-memory registry from the database' do
        described_class.start!
        expect(described_class.registry).to eq(registry_hash)
      end
    end

    it 'starts a background thread' do
      allow(described_class).to receive(:run_loop) # prevent actual looping
      described_class.start!
      expect(described_class.instance_variable_get(:@thread)).to be_alive
    end

    it 'does not start a second thread when called again' do
      allow(described_class).to receive(:run_loop)
      described_class.start!
      thread_before = described_class.instance_variable_get(:@thread)

      described_class.start!
      thread_after = described_class.instance_variable_get(:@thread)

      expect(thread_before).to equal(thread_after)
    end
  end
end
