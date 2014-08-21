require 'chefspec'

module BswTech
  module ChefSpec
    module LwrpTestHelper
      def generated_cookbook_path
        File.join File.dirname(__FILE__), 'gen_cookbooks'
      end

      def cookbook_path
        File.join generated_cookbook_path, generated_cookbook_name
      end

      def generated_cookbook_name
        'lwrp_gen'
      end

      def executor

      end

      RSpec.configure do |config|
        config.before(:each) do
          stub_resources
          @gpg_interface = double()
          BswTech::Gpg::GpgInterface.stub(:new).and_return(@gpg_interface)
          @current_type_checked = nil
          @external_type = nil
          @base64_used = nil
          @shell_outs = []
          @usernames_used = []
          @keyring_checked = :default
          @keytrusts_imported = []
        end

        config.after(:each) do
          cleanup
        end
      end

      def temp_lwrp_recipe(contents)
        runner_options = {}
        create_temp_cookbook(contents)
        RSpec.configure do |config|
          config.cookbook_path = [*config.cookbook_path] << generated_cookbook_path
        end
        lwrps_full = [*lwrps_under_test].map do |lwrp|
          "#{cookbook_under_test}_#{lwrp}"
        end
        @chef_run = ::ChefSpec::Runner.new(runner_options.merge(step_into: lwrps_full))
        @chef_run.converge("#{generated_cookbook_name}::default")
      end

      def create_temp_cookbook(contents)
        the_path = cookbook_path
        recipes = File.join the_path, 'recipes'
        FileUtils.mkdir_p recipes
        File.open File.join(recipes, 'default.rb'), 'w' do |f|
          f << contents
        end
        File.open File.join(the_path, 'metadata.rb'), 'w' do |f|
          f << "name '#{generated_cookbook_name}'\n"
          f << "version '0.0.1'\n"
          f << "depends '#{cookbook_under_test}'\n"
        end
      end

      def cleanup
        FileUtils.rm_rf generated_cookbook_path
      end

      def stub_gpg_interface(current=[], draft)
        allow(@gpg_interface).to receive(:get_current_installed_keys) do |username, type, keyring|
          @current_type_checked = type
          @keyring_checked = keyring if keyring
          @usernames_used << username
          current
        end
        allow(@gpg_interface).to receive(:get_key_info_from_base64) do |type, base64|
          @external_type = type
          @base64_used = base64
          draft
        end
        allow(@gpg_interface).to receive(:import_trust) do |username, key, keyring|
          @usernames_used << username
          @keytrusts_imported << {
              :key => key,
              :keyring => keyring
          }
          draft
        end



        # def delete_keys(username, key_to_delete, keyring=:default)
        #   type = key_to_delete.type
        #   delete_param = type == :public_key ? '--delete-key' : '--delete-secret-and-public-key'
        #   gpg_command = get_keyring_param(type, keyring)
        #   @command_runner.run as_user=username,
        #                       command="#{gpg_command} #{delete_param} --batch --yes #{key_to_delete.fingerprint}"
        # end
        #
        # def import_keys(username, key, key_contents, keyring=:default)
        #   gpg_cmd = get_gpg_cmd(key.type, keyring)
        #   @command_runner.run as_user=username,
        #                       command="#{gpg_cmd} --import", input=key_contents
        # end
      end

      def executed_command_lines
        @shell_outs.inject({}) do |total, item|
          total[item.command] = item.input
          total
        end
      end

      def setup_stub_commands(commands)
        @command_mocks = commands
        stub_setup = lambda do |shell_out|
          @shell_outs << shell_out
          command_text = shell_out.command
          matched_mock = @command_mocks.find { |mock| mock[:command] == command_text }
          if matched_mock
            shell_out.stub(:error!)
            shell_out.stub(:run_command) do
              if matched_mock[:expected_input] != shell_out.input
                fail "Expected input #{matched_mock[:expected_input]} but got #{shell_out.input}"
              end
            end
            output = matched_mock[:stdout] || ''
            shell_out.stub(:stdout).and_return(output)
          else
            shell_out.stub(:error!).and_raise "Unexpected command #{shell_out.command}"
          end
        end
        original_new = Mixlib::ShellOut.method(:new)
        Mixlib::ShellOut.stub(:new) do |*args|
          command = original_new.call(*args)
          stub_setup[command]
          command
        end
      end

      def verify_actual_commands_match_expected
        actual = executed_command_lines
        expected = @command_mocks.map { |cmd| cmd[:command] }
        actual.keys.should == expected
      end
    end
  end
end