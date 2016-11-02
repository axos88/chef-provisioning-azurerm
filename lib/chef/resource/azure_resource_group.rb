require 'chef/provisioning/azurerm/azure_resource'

class Chef
  class Resource
    class AzureResourceGroup < Chef::Provisioning::AzureRM::AzureResource
      resource_name :azure_resource_group
      actions :create, :destroy, :nothing
      default_action :create
      attribute :name, kind_of: String, name_attribute: true, regex: /^[\w\-\(\)\.]{0,80}$+(?<!\.)$/i
      attribute :location, kind_of: String, default: 'westus'
      attribute :tags, kind_of: Hash

      child_resources :resources, { :resource_group => :name, :location => :location }
    end
  end
end
