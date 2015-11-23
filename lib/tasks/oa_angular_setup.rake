require "oa_angular_setup/initialize_angular"

namespace :oa_angular_setup do

  desc 'Create angular server'
  task :create => :environment do
    initializer = AngularInitializer.new
    initializer.run
  end

  desc 'Create angular server'
  task :test => :environment do
    initializer = AngularInitializer.new
    puts "in task"
    puts OaAngularSetup.configuration.app_name
    puts initializer.test
  end

end
