class CreateRolesAndPermissionSets < ActiveRecord::Migration
  def self.up
    create_table :permission_sets do |t|
      t.string :name
      t.text :permissions
      t.timestamps 
    end
    
    create_table :roles do |t|
      t.integer :permission_set_id
      t.integer :<%= singular_name %>_id
      t.timestamps 
    end
  end

  def self.down
    drop_table :permission_sets
    drop_table :roles
  end
end
