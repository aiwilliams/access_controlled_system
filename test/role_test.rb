require File.dirname(__FILE__) + "/test_helper"

class RoleTest < Test::Unit::TestCase
  include AccessControlledSystem::TestCase

  def test_associations
    assert_equal permission_sets(:superuser), roles(:superuser).permission_set
    assert_equal people_model(:superuser), roles(:superuser).send(AccessControlledSystem.person_model_name)
  end
  
  def test_authorized_delegates_to_permission_set
    assert roles(:superuser).authorized?(:any_thing_at_all)
  end
end
