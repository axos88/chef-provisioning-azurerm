require 'chef/resource/lwrp_base'
require 'chef/provisioning/azurerm/credentials'
require 'chef/provisioning/azurerm/snakify'

require 'pry'

class Chef
  class Resource
    HIDDEN_IVARS = HIDDEN_IVARS + [:@recipe]
  end
end

class Chef
  module Provisioning
    module AzureRM
      class AzureResource < Chef::Resource::LWRPBase
        @@attribute_overrides = []

        def initialize(*args)
          super
          return unless run_context
          @chef_environment = run_context.cheffish.current_environment
          @chef_server = run_context.cheffish.current_chef_server
          @driver = run_context.chef_provisioning.current_driver
          Chef::Log.error 'No driver set. (has it been set in your recipe using with_driver?)' unless driver
          @driver_name, @subscription_id = driver.split(':', 2)
        end

        attr_accessor :driver
        attr_accessor :driver_name
        attr_accessor :subscription_id

        def set_recipe(recipe)
          @recipe = recipe

          Chef::Log.info("Seting recipe for #{self.class} '#{name}' to an instance of #{recipe.class} ")
        end

        def self.child_resources(attribute_name, inherited_attribute_map)
          define_method attribute_name.to_sym do |&block|
            attributes = inherited_attribute_map.map { |k,v| [k, send(v)] }
            @@attribute_overrides += [attributes]
            @recipe.instance_eval(&block)
            @@attribute_overrides.pop
          end
        end

        def self.child_resource(attribute_name, resource_type, inherited_attribute_map)
          define_method(attribute_name.to_sym) do |name, &block|
            attributes = inherited_attribute_map.map { |k,v| [k, send(v)] }
            @@attribute_overrides += [attributes]
            @recipe.send(resource_type, name, &block)
            @@attribute_overrides.pop
          end
        end

        def self.inherited(child)
          ::Chef::DSL::Recipe.class_eval do
            resource_name = child.name.split('::').last.snakify
            Chef::Log.info("defining method #{resource_name.to_sym} on Chef::Recipe")

            define_method resource_name.to_sym do |name, &block|
              recipe = self

              resource = declare_resource(resource_name.to_sym, name, caller[0]) do
                Chef::Log.info("Creating resource #{resource_name}/#{name}")

                @@attribute_overrides.each do |h|
                  h.each do |k, v|
                    Chef::Log.info("Setting default value for #{k}=>#{v} for #{resource_name}/#{name}") if respond_to?(k.to_sym)
                    send(k.to_sym, v) if respond_to?(k.to_sym)
                  end
                end

                set_recipe(recipe)
              end

              #This is needed outside the block above to create the parent resource before the child resource.
              resource.tap do |r|
                r.instance_eval(&block)
              end
            end
          end
        end
      end
    end
  end
end
