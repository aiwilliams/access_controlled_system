require File.dirname(__FILE__) + "/test_helper"

class PermissionSetTest < Test::Unit::TestCase
  include AccessControlledSystem::TestCase

  def test_authorized
    assert permission_sets(:superuser).authorized?(:any_action_at_all)
    assert permission_sets(:administrator).authorized?(:administrator)
    assert !permission_sets(:administrator).authorized?(nil)
    assert !permission_sets(:administrator).authorized?(:super_management)
    assert !permission_sets(:administrator).authorized?(:any_thing_at_all)
    assert !permission_sets(:administrator).authorized?([:any_thing_at_all])
    assert !permission_sets(:administrator).authorized?([:super_management, :any_thing_at_all])
    assert permission_sets(:administrator).authorized?(:administrator, :any_thing_at_all)
  end
end
