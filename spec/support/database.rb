ActiveRecord::Schema.define do
  create_table :test_track_split_registry_cache, force: true do |t|
    t.text :registry_json, null: false
    t.timestamps null: false
  end
end
