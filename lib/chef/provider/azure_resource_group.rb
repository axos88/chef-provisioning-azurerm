require 'chef/provisioning/azurerm/azure_provider'

class Chef
  class Provider
    class AzureResourceGroup < Chef::Provisioning::AzureRM::AzureProvider
      provides :azure_resource_group

      def whyrun_supported?
        true
      end

      def load_current_resource
        begin
          azure_rg = resource_management_client.resource_groups.get(new_resource.name).value!.body

          @current_resource = Chef::Resource::AzureResourceGroup.new(new_resource.name)
          @current_resource.location = azure_rg.location
          @current_resource.tags = Hash[azure_rg.tags.map { |k,v| [k.to_sym, v]}]
        rescue MsRestAzure::AzureOperationError => ex
          raise ex unless ex.body['error']['code'] == 'ResourceGroupNotFound'
          Chef::Log.debug("Cannot find #{new_resource} in the cloud")
          nil
        end
      end

      action :create do
        converge_if_changed do
          begin
            resource_group = Azure::ARM::Resources::Models::ResourceGroup.new
            resource_group.location = new_resource.location
            resource_group.tags = new_resource.tags
            result = resource_management_client.resource_groups.create_or_update(new_resource.name, resource_group).value!
            Chef::Log.debug("result: #{result.body.inspect}")
          rescue ::MsRestAzure::AzureOperationError => operation_error
            raise operation_error if operation_error.body.nil?
            Chef::Log.error operation_error.body['error']
            raise "#{operation_error.body['error']['code']}: #{operation_error.body['error']['message']}"
          end
        end
      end

      def resource_group_exists?
        !current_resource.nil?
      end

      action :destroy do
        begin
          if resource_group_exists?
            converge_by("destroy Resource Group #{new_resource.name}") do
              result = resource_management_client.resource_groups.delete(new_resource.name).value!
              Chef::Log.debug("result: #{result.body.inspect}")
            end
          end
        rescue ::MsRestAzure::AzureOperationError => operation_error
          raise operation_error if operation_error.body.nil?
          Chef::Log.error operation_error.body['error']
          raise "#{operation_error.body['error']['code']}: #{operation_error.body['error']['message']}"
        end
      end
    end
  end
end
