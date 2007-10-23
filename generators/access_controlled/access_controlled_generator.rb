class AccessControlledGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.migration_template 'migration.rb', 'db/migrate', :migration_file_name => "create_roles_and_permission_sets"
    end
  end
  
  protected
    def banner
      "Usage: #{$0} access_controlled PersonModelName"
    end
end
