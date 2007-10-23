require File.dirname(__FILE__) + "/test_helper"

class AccessControlledController < ActionController::Base
  def rescue_action(e) raise e end
  
  include AccessControlledSystem

  def action_a; render :text => "action_a"; end
  def action_b; render :text => "action_b"; end
  def action_c; render :text => "action_c"; end
  def action_d; render :text => "action_d"; end
end

class LiberalController < AccessControlledController
  permit :superpowers, :administrator
end

class RestrictToController < LiberalController
  restrict :administrator, :to => [:action_c, :action_d]
end

class RestrictFromController < LiberalController
  restrict :administrator, :from => :action_c
end

class RestrictFromAllController < LiberalController
  restrict :administrator, :from => :all
end

class PermitEveryoneController < LiberalController
  permit :everyone
end

class PermitBasedOnConditionController < AccessControlledController
  permit :everyone, :to => :action_b
  permit :everyone, :to => :action_a, :condition => proc {!!current_person}
end

class PermitAllActionsByConditionController < AccessControlledController
  permit :everyone, :condition => proc {!!current_person}
end

class AccessControlledSystemTest < Test::Unit::TestCase
  include AccessControlledSystem::TestCase
  
  def setup
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  end
  
  def test_access_controlled
    @controller = AccessControlledController.new
    assert_authorized :action_a, :superuser
    assert_unauthorized :action_a, :admin
  end
  
  def test_all_actions_condition
    @controller = PermitAllActionsByConditionController.new
    assert_authorized :action_a, :admin
    assert_authorized :action_a, :user
    assert_authorized :action_a, :superuser
    assert_unauthorized :action_a, :anyone_else
  end
  
  def test_condition
    @controller = PermitBasedOnConditionController.new
    assert_authorized :action_a, :admin
    assert_authorized :action_a, :user
    assert_authorized :action_a, :superuser
    assert_unauthorized :action_a, :anyone_else
    assert_authorized :action_b, :anyone_else
  end
  
  def test_permit
    @controller = LiberalController.new
    assert_authorized :action_a, :superuser, :admin
    assert_authorized :action_b, :superuser, :admin
    assert_authorized :action_c, :superuser, :admin
    assert_authorized :action_d, :superuser, :admin
    assert_unauthorized :action_a, :user
    assert_unauthorized :action_c, :user
    assert_unauthorized :action_a, :anyone_else
  end
  
  def test_permit_everyone
    @controller = PermitEveryoneController.new
    assert_authorized :action_a, :superuser, :admin, :anyone_really
    assert_authorized :action_b, :superuser, :admin, :anyone_really
    assert_authorized :action_c, :superuser, :admin, :anyone_really
    assert_authorized :action_d, :superuser, :admin, :anyone_really
  end

  def test_restrict_to
    @controller = RestrictToController.new
    assert_authorized :action_a, :superuser
    assert_unauthorized :action_a, :admin
    assert_unauthorized :action_b, :admin
    assert_authorized :action_c, :superuser, :admin
    assert_authorized :action_d, :superuser, :admin
  end

  def test_restrict_from
    @controller = RestrictFromController.new
    assert_authorized :action_a, :superuser, :admin
    assert_authorized :action_b, :superuser, :admin
    assert_unauthorized :action_c, :admin
    assert_authorized :action_d, :superuser, :admin
  end

  def test_restrict_from_all
    @controller = RestrictFromAllController.new
    assert_authorized :action_a, :superuser
    assert_unauthorized :action_a, :admin
    assert_unauthorized :action_b, :admin
    assert_unauthorized :action_c, :admin
    assert_unauthorized :action_d, :admin
  end
  
  protected
    def assert_authorized(action, *people)
      assert_response_for_people(:success, action, *people)
    end
    
    def assert_unauthorized(action, *people)
      assert_response_for_people(:unauthorized, action, *people)
    end
    
    def assert_response_for_people(expected, action, *people)
      with_routing do |set|; set.draw do |map|
        map.connect ':controller/:action/:id'
        for person in people
          @controller.current_person = people_model(person) rescue nil
          get action; assert_response expected, "Expected #{expected} for person #{person}"
        end
      end; end
    end
end
