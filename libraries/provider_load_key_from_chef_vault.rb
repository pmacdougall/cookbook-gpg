class Chef
  class Provider
    class BswGpgLoadKeyFromChefVault < BaseGpgProvider
      def initialize(new_resource, run_context)
        super
      end

      def load_current_resource
        @current_resource ||= Chef::Resource::BswGpgLoadKeyFromChefVault.new(new_resource.name)
        @current_resource.data_bag(new_resource.data_bag)
        @current_resource.item(new_resource.item)
        @current_resource.json_key(new_resource.json_key)
        super
      end

      def get_key
        item = chef_vault_item('_default-pgp-keys', 'brighter-public')
        item[@new_resource.json_key]
      end
    end
  end
end
