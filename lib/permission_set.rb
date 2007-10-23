class PermissionSet < ActiveRecord::Base
  serialize :permissions, Array
  
  def authorized?(*required_permissions)
    return true if permissions.include?(:superuser)

    required_permissions.flatten!
    required_permissions.compact!
    return false if required_permissions.blank?

    required_permissions.map!(&:to_sym)
    !(permissions & required_permissions).blank?
  end
  
  def permissions
    (read_attribute(:permissions) || []).collect(&:to_sym)
  end
end
