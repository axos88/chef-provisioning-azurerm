require 'chef/provisioning/azurerm/azure_provider'

class Chef
  class Provider
    class AzureStorageAccount < Chef::Provisioning::AzureRM::AzureProvider
      provides :azure_storage_account

      def whyrun_supported?
        true
      end

      def load_current_resource
        begin
          binding.pry
          azure_sa = storage_management_client.storage_accounts.get_properties(new_resource.resource_group, new_resource.name).value!.body

          @current_resource = Chef::Resource::AzureStorageAccount.new(new_resource.name)

          @current_resource.location = azure_sa.location
          @current_resource.tags = Hash[azure_sa.tags.map { |k,v| [k.to_sym, v]}]
          @current_resource.account_type = azure_sa.properties.account_type
          @current_resource.custom_domain = azure_sa.properties.custom_domain
        rescue MsRestAzure::AzureOperationError => ex
          raise ex if ex.body.nil?
          raise "#{ex.body['error']['code']}: #{ex.body['error']['message']}" unless ex.body['error']['code'] == 'ResourceNotFound'
          Chef::Log.debug("Cannot find #{new_resource} in the cloud")
          nil
        end
      end

      action :create do
        # If the storage account already exists, do an update
        if storage_account_exists?
          update_storage_account
        else
          # Create the storage account complete with tags and properties
          converge_by("create Storage Account #{new_resource.name}") do
            do_create

            #We cannot set some properties during create...
            load_current_resource
            update_storage_account unless new_resource.custom_domain.nil?
          end
        end
      end

      action :destroy do
        if storage_account_exists?
          converge_by("destroy Storage Account: #{new_resource.name}") do
            begin
              storage_management_client.storage_accounts.delete(new_resource.resource_group, new_resource.name).value!
            rescue MsRestAzure::AzureOperationError => ex

              raise ex if ex.body.nil?
              raise "#{ex.body['error']['code']}: #{ex.body['error']['message']}"
            end
          end
        end
      end

      def storage_account_exists?
        !current_resource.nil?
      end

      def do_create
        storage_account = Azure::ARM::Storage::Models::StorageAccountCreateParameters.new.tap do |sa|
          sa.location = new_resource.location
          sa.tags = new_resource.tags
          sa.properties = Azure::ARM::Storage::Models::StorageAccountPropertiesCreateParameters.new
          sa.properties.account_type = new_resource.account_type
        end

        result = storage_management_client.storage_accounts.create(new_resource.resource_group, new_resource.name, storage_account).value!
        Chef::Log.debug(result)
      rescue ::MsRestAzure::AzureOperationError => operation_error
        raise operation_error if operation_error.body.nil?
        Chef::Log.error operation_error.body['error']
        raise "#{operation_error.body['error']['code']}: #{operation_error.body['error']['message']}"
      end

      def do_update(data)
        result = storage_management_client.storage_accounts.update(new_resource.resource_group, new_resource.name, data).value!
        Chef::Log.debug(result)
      rescue ::MsRestAzure::AzureOperationError => operation_error
        raise operation_error if operation_error.body.nil?
        Chef::Log.error operation_error.body['error']
        raise "#{operation_error.body['error']['code']}: #{operation_error.body['error']['message']}"
      end


      def update_storage_account
        converge_if_changed :account_type do
          do_update account_type_update_parameters
        end

        converge_if_changed :tags do
          do_update tags_update_parameters
        end

        converge_if_changed :custom_domain do
          do_update custom_domain_update_parameters
        end
      end

      def account_type_update_parameters
        storage_account = Azure::ARM::Storage::Models::StorageAccountUpdateParameters.new.tap do |sa|
          sa.location = new_resource.location
          sa.properties = Azure::ARM::Storage::Models::StorageAccountPropertiesUpdateParameters.new
          sa.properties.account_type = new_resource.account_type
        end
      end

      def tags_update_parameters
        storage_account = Azure::ARM::Storage::Models::StorageAccountUpdateParameters.new.tap do |sa|
          sa.location = new_resource.location
          sa.tags = new_resource.tags
        end
      end

      def custom_domain_update_parameters
        storage_account = Azure::ARM::Storage::Models::StorageAccountUpdateParameters.new.tap do |sa|
          sa.location = new_resource.location
          sa.properties = Azure::ARM::Storage::Models::StorageAccountPropertiesUpdateParameters.new

          unless new_resource.custom_domain.nil?
            sa.properties.custom_domain = Azure::ARM::Storage::Models::CustomDomain.new.tap do |cd|
              cd.name = new_resource.custom_domain
            end
          end
        end
      end
    end
  end
end
