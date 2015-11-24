require "oa_angular_setup/initialize_angular"

namespace :oa_angular_setup do

  desc 'Create angular server'
  task :create => :environment do
    initializer = AngularInitializer.new
    initializer.run

    #add in swagger ui
    if OaAngularSetup.configuration.add_swaggger_ui
      if !File.exists?("#{Rails.root}/public/api/docs/")
        #get files and move into place
        Dir.mkdir("#{Rails.root}/public/api") unless File.exists?("#{Rails.root}/public/api")
        system "npm install swagger-ui" unless File.exists?("#{Rails.root}/node_modules/swagger-ui/")      
        system "cp -R #{Rails.root}/node_modules/swagger-ui/dist #{Rails.root}/public/api/docs" 

        #replace dummy url
        file_name = "#{Rails.root}/public/api/docs/index.html"
        text = File.read(file_name)
        new_contents = text.gsub('http://petstore.swagger.io/v2/swagger.json', OaAngularSetup.configuration.swagger_doc_url)
        File.open(file_name, "w") {|file| file.puts new_contents }
      end
    end
  end
end
