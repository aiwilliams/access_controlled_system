class Role < ActiveRecord::Base
  belongs_to AccessControlledSystem.person_model_name
  belongs_to :permission_set
  
  delegate :authorized?, :name, :to => :permission_set
end
