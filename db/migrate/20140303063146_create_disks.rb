class CreateDisks < ActiveRecord::Migration
  def change
    create_table :disks do |t|
      t.string   :uuid, unique: true, null: false
      t.string   :mount_point
      t.string   :fs_type, default: "ext4"
      t.integer  :setup_status_flag, default: 0
      t.timestamps
    end
  end
end
