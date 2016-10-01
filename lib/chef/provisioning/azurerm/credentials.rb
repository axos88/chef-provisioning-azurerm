require 'inifile'

class Chef
  module Provisioning
    module AzureRM
      class Credentials
        CONFIG_PATH = "#{ENV['HOME']}/.azure/credentials".freeze

        def initialize
          config_file = ENV['AZURE_CONFIG_FILE'] || File.expand_path(CONFIG_PATH)
          if File.file?(config_file)
            @credentials = IniFile.load(File.expand_path(config_file))
          else
            Chef::Log.warn "#{CONFIG_PATH} was not found or not accessible." unless File.file?(config_file)
          end
        end

        def azure_credentials_for_subscription(subscription_id)
          tenant_id = ENV['AZURE_TENANT_ID'] || @credentials[subscription_id]['tenant_id']
          client_id = ENV['AZURE_CLIENT_ID'] || @credentials[subscription_id]['client_id']
          client_secret = ENV['AZURE_CLIENT_SECRET'] || @credentials[subscription_id]['client_secret']
          token_provider = MsRestAzure::ApplicationTokenProvider.new(tenant_id, client_id, client_secret)
          MsRest::TokenCredentials.new(token_provider)
        end

        def self.singleton
          @credentials ||= Credentials.new
        end
      end
    end
  end
end
