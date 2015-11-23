require 'rails/generators/named_base'

module OaAngularSetup
  module Generators
    class OaAngularSetupGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      namespace "oa_angular_setup"
      source_root File.expand_path("../templates", __FILE__)

    end
  end
end
