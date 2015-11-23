module OaAngularSetup
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)
      desc "Creates OaAngularSetup initializer for your application"

      def copy_initializer
        template "oa_angular_setup_initializer.rb", "config/initializers/oa_angular_setup.rb"

        puts "Install complete! Truly Outrageous!"
      end
    end
  end
end