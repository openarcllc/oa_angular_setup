OaAngularSetup.configure do |config|
  # Set the options to what makes sense for you

  #Name of your app (default: 'App') 
  config.app_name = 'App'

  #Create app.js file true/false (default: true)
  config.create_app_js = true 

  #Create factories true/false (default: true)
  config.create_factories = true 

  #Create controllers true/false (default: true)
  config.create_controllers = true

  #The URL where the gem can find your swagger documentation (default: "http://localhost:3000/api/swagger_doc")
  config.swagger_doc_url = "http://localhost:3000/api/swagger_doc"

  #The Destination where the files will be created, starting from your Rails.root . (default: "/public/angular/")
  config.destination = "/public/angular/"
end