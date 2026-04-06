require 'rails_helper'

RSpec.describe TestTrack::Remote::SplitRegistry do
  let(:split_registry) do
    {
      'splits' => {
        'time' => {
          'weights' => {
            'back_in_time' => 100,
            'power_of_love' => 0
          },
          'feature_gate' => false
        }
      },
      'experience_sampling_weight' => 1
    }
  end

  before do
    allow(described_class).to receive(:instance).and_call_original
    allow(described_class).to receive(:fake_instance_attributes).and_return(split_registry)
    TestTrack::SplitRegistryUpdater.reset_for_testing!
    allow(TestTrack::SplitRegistryCache).to receive(:fetch_registry).and_return(nil)
    allow(TestTrack::SplitRegistryCache).to receive(:store_registry)
  end

  after { TestTrack::SplitRegistryUpdater.reset_for_testing! }

  describe "#to_hash" do
    context 'with api enabled' do
      around do |example|
        with_test_track_enabled { example.run }
      end

      before do
        allow(TestTrack::Remote::SplitRegistry).to receive(:instance)
          .and_return(double(attributes: split_registry))
      end

      it "returns the registry from the updater's in-memory cache" do
        TestTrack::SplitRegistryUpdater.refresh_now!
        expect(described_class.to_hash).to eq(split_registry)
      end

      it "returns nil when the updater has not yet loaded a registry" do
        expect(described_class.to_hash).to be_nil
      end

      it "returns a frozen hash" do
        TestTrack::SplitRegistryUpdater.refresh_now!
        expect { described_class.to_hash[:foo] = "bar" }.to raise_error(/frozen/)
      end
    end

    it "returns nil if no registry has been loaded" do
      expect(described_class.to_hash).to eq(nil)
    end
  end

  describe ".reset" do
    before do
      allow(TestTrack::Remote::SplitRegistry).to receive(:instance)
        .and_return(double(attributes: split_registry))
    end

    it "triggers an immediate synchronous refresh via the updater" do
      expect(TestTrack::SplitRegistryUpdater).to receive(:refresh_now!)
      described_class.reset
    end

    it "results in an updated in-memory registry" do
      described_class.reset
      expect(TestTrack::SplitRegistryUpdater.registry).to eq(split_registry)
    end
  end

  describe ".instance" do
    subject { described_class.instance }
    let(:url) { "http://testtrack.dev/api/v3/builds/#{TestTrack.build_timestamp}/split_registry" }

    before do
      stub_request(:get, url)
        .with(basic_auth: %w(dummy fakepassword))
        .to_return(status: 200, body: {
          splits: {
            remote_split: {
              weights: { variant1: 50, variant2: 50 },
              feature_gate: false
            }
          },
          experience_sampling_weight: 1
        }.to_json)
    end

    it "instantiates a SplitRegistry with fake instance attributes" do
      expect(subject.attributes).to eq(
        'splits' => {
          'time' => {
            'weights' => {
              'back_in_time' => 100, 'power_of_love' => 0
            },
            'feature_gate' => false
          }
        },
        'experience_sampling_weight' => 1
      )
    end

    it "fetches attributes from the test track server when enabled" do
      with_test_track_enabled do
        expect(subject.attributes).to eq(
          "splits" => {
            "remote_split" => {
              "weights" => { "variant1" => 50, "variant2" => 50 },
              "feature_gate" => false
            }
          },
          "experience_sampling_weight" => 1
        )
      end
    end
  end
end
