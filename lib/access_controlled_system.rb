# When mixed into an ActionController heirarchy, gives you a flexible, yet
# simple API to define which permissions are required to invoke actions.
#
#    permit :right_one, :right_two, :to => [:create, :new]
#    permit :right_three, :to => :all
#    permit :right_four   # :to => :all is assumed
#
# When a subclass permits further rights, they are additive. In order to
# restrict rights in the subclass of a more permitting superclass, use
# restrict. This allows you to define which actions *can* be invoked and which
# *cannot* through the use of :to and :from.
#
#    restrict :right_one, :from => :create
#    restrict :right_three, :to => [:destroy, :update]
#    restrict :right_four   # :from => :all is assumed
#
# Again, subclasses do not affect the security of a superclass, though a
# subclass, since it is inheriting it's access control definitions, must
# reduce or may expand upon those inherited.
#
# Please note that this system is designed in such a way that should a person
# have two rights, right_one and right_two, and a single action is permitted
# to one of those and restricted from the other, that person will still have
# access based on the fact that they have at least one permitted right to the
# action.
module AccessControlledSystem
  mattr_reader :person_model_name
  
  def self.person_model_name=(name)
    @@person_model_name = name
    hook_reload if Dependencies.autoloaded?(person_model_class)
    person_model_class.send :include, AccessControlledPerson
  end
  
  def self.person_model_class
    (person_model_name || :person).to_s.classify.constantize
  end
  
  def self.hook_reload
    ActiveRecord::Base.class_eval <<-"end;"
      class << self
        def inherited_with_access_control(child)
          inherited_without_access_control(child)
          if child == #{person_model_class.to_s}
            #{person_model_class}.send :include, AccessControlledPerson
          end
        end
        alias_method_chain :inherited, :access_control
      end
    end;
  end
  
  def self.included(controller_class)
    controller_class.extend ClassMethods
    controller_class.send :include, InstanceMethods
    
    current_person_method_name = :"current_#{person_model_name}"
    controller_class.class_eval do
      attr_accessor current_person_method_name unless method_defined? current_person_method_name
      alias_method :current_person, current_person_method_name unless current_person_method_name == :current_person
      alias_method :current_person=, :"#{current_person_method_name}=" unless current_person_method_name == :current_person
      def logged_in?; true; end     unless method_defined? :logged_in?
    end

    controller_class.send :before_filter, :enforce_permissions
    controller_class.send :class_inheritable_accessor, :permissions
    controller_class.permissions = Permissions.new
  end

  module ClassMethods
    def permit(*permits)
      apply_permissions(:permit, *permits)
    end
    
    def restrict(*permits)
      apply_permissions(:restrict, *permits)
    end
    
    def apply_permissions(application, *permits)
      actions = nil
      if permits.last.is_a?(Hash)
        actions = permits.last
        permits = permits[0..-2]
      end
      permits.each do |permit|
        permissions[permit].send application, actions
      end
    end
  end
  
  module InstanceMethods
    protected
      def enforce_permissions
        required_permits = permissions.collect do |permit, permission|
          permission.required?(self, action_name) ? permit : nil
        end.compact
        
        if required_permits && required_permits.include?(:everyone)
          logger.info "AccessControlledSystem:: Everyone permitted"
        elsif current_person
          if current_person.authorized?(required_permits)
            logger.info "AccessControlledSystem:: Authorized #{current_person} having a permission in [#{required_permits}]"
          else
            logger.info "AccessControlledSystem:: Unauthorized #{current_person} having no permission in [#{required_permits}]"
            on_access_denied(required_permits); return false
          end
        else
          on_access_denied(required_permits); return false
        end
      end
      
      def on_access_denied(required_permits)
        head :unauthorized
      end
  end
  
  module AccessControlledPerson
    def self.included(model_class)
      model_class.has_many :roles do
        def authorized?(required_permissions)
          load_target.detect { |role| role.authorized?(required_permissions) } ? true : false
        end
      end
      model_class.has_many :permission_sets, :through => :roles
      model_class.extend ClassMethods
      model_class.send :include, InstanceMethods
    end
    
    module ClassMethods
      def new_in_roles(attributes, *permission_set_names)
        person = new(attributes)
        permission_set_names.flatten.compact.each do |name|
          permissions = PermissionSet.find_by_name(name.to_s)
          raise "No permission set found having name #{name}" unless permissions
          person.roles << Role.new(:permission_set => permissions)
        end
        person
      end

      def create_in_roles!(attributes, *permission_set_names)
        person = new_in_roles(attributes, *permission_set_names)
        person.save!
        person
      end
    end
    
    module InstanceMethods
      def authorized?(required_permissions)
        self.roles.authorized?(required_permissions)
      end
    end
  end
  
  class Permission
    attr_accessor :rules
    def initialize(permission)
      @permission = permission
      @rules = []
    end
    
    def permit(actions)
      @rules << [:permit, actions]
    end
    
    def restrict(actions)
      @rules << [:restrict, actions]
    end
    
    def eval_all(rule, results)
      results[:restricted_from].clear
      results[:permitted_to].clear
      results[:default] = rule
    end
    
    def eval_rule(rule, actions, results)
      list = results[rule == :restrict ? :restricted_from : :permitted_to]
      other = results[rule == :restrict ? :permitted_to : :restricted_from]
      standard_option = rule == :restrict ? :from : :to
      if all?(actions)
        eval_all(rule, results)
      elsif rule == :restrict && actions.include?(:to)
        eval_all(rule, results)
        eval_rule(:permit, actions, results)
      else
        list.push(*[actions[standard_option]].flatten.uniq)
        list.each(&other.method(:delete))
      end
    end
    
    # Answers whether this permission would be required to invoke action.
    #
    # If a person has this permission, and this permission is permitted_to
    # action, it will answer true. If this permission is restricted_from
    # an action, this will answer false. This is kinda weird, but my
    # goal of a clear API on the controllers and on the permission_set led
    # me here.
    def required?(controller, action)
      action = action.to_sym
      results = evaluate_rules(controller, action)
      
      return true if results[:permitted_to].include?(action)
      return false if results[:restricted_from].include?(action)
      results[:default] == :permit
    end
    
    def evaluate_rules(controller, action)
      results = {:default => :restrict, :restricted_from => [], :permitted_to => []}
      
      @rules.each do |rule|
        condition = rule[1] && rule[1][:condition]
        if !condition || (should_eval_condition?(rule[1], action) && controller.instance_eval(&condition))
          eval_rule(rule[0], rule[1], results)
        end
      end
      results
    end
    
    def should_eval_condition?(actions, action)
      all?(actions) || [actions[:to], actions[:from]].flatten.include?(action)
    end
    
    def all?(actions)
      !actions || (!actions[:to] && !actions[:from]) || actions[:to] == :all || actions[:from] == :all
    end

    def dup
      returning Permission.new(@permission) do |clone|
        clone.rules = @rules.dup
      end
    end
    
    def to_s
      "#{@permission} is required on #{@any_action_requires_this_permission ? "all actions" : @permits.inspect}"
    end
  end
  
  class Permissions < Hash
    def initialize
      super do |hash, key|
        hash[key] = Permission.new(key)
      end
    end
    
    def dup
      returning(Permissions.new) do |duplicate|
        self.each { |permission, permissions| duplicate[permission] = permissions.dup }
      end
    end
  end
  
end
