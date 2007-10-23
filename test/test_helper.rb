require File.dirname(__FILE__) + "/../../../../test/test_helper"
require "access_controlled_system"

module AccessControlledSystem
  module TestCase
    def self.included(test_case)
      test_case.fixture_path = File.dirname(__FILE__)
      test_case.fixture_class_names = {:people => AccessControlledSystem.person_model_class}
      test_case.setup_fixture_accessors([AccessControlledSystem.person_model_name.to_s.pluralize])
      test_case.fixtures :people, :roles, :permission_sets
    end
    
    def people_model(symbol)
      send(AccessControlledSystem.person_model_name.to_s.pluralize, symbol)
    end
  end
end