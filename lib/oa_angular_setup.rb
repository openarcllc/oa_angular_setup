require "oa_angular_setup/version"
require "oa_angular_setup/initialize_angular"

module OaAngularSetup
  # if ARGV[0].nil?
  #   puts "Please enter the name of the app: "
  #   app_name = gets
  #   app_name.chomp!
  #   puts "Create factories? (Y/N)"
  #   cf = gets
  #   if cf.downcase.strip == 'y'
  #     create_factories = true
  #   end
  #   puts "Create controllers? (Y/N)"
  #   cc = gets
  #   if cc.downcase.strip == 'y'
  #     create_controllers = true
  #   end
  #   puts "Create #{@app_name}.js file? (Y/N)"
  #   ca = gets
  #   if ca.downcase.strip == 'y'
  #     create_app_js = true
  #   end
  #   puts "Please enter url of swagger api documentation: "
  #   url = gets
  #   url.chomp!
  # end

  # initializer = AngularInitializer.new(app_name, create_factories, create_app_js, create_controllers, url)
  # puts initializer.inspect
  # initializer.run
  require 'rails'
  class Railtie < Rails::Railtie
    rake_tasks do
      load "lib/oa_angular_setup.rake"
    end
  end
end
require 'oa_angular_setup/railtie' if defined?(Rails)