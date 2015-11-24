require "oa_angular_setup/version"
require "oa_angular_setup/initialize_angular"
require 'rails'

module OaAngularSetup

  class << self
    attr_accessor :configuration
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end


  class Configuration
    attr_accessor :app_name, :create_factories, :create_app_js,
      :create_controllers, :swagger_doc_url, :destination, :add_swaggger_ui

    def initialize
      @app_name = 'App'
      @create_factories = true 
      @create_app_js = true 
      @create_controllers = true
      @add_swaggger_ui = true
      @swagger_doc_url = "http://localhost:3000/api/swagger_doc"
      @destination = "/public/angular/"
    end
  end

  module Rails
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "tasks/oa_angular_setup.rake"
      end
    end
  end
end