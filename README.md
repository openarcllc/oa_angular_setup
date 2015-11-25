# OaAngularSetup

The OaAngularSetup gem will read a swagger compliant API and generate angular factories & controllers. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'oa_angular_setup'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install oa_angular_setup

## Usage

Simply run:
```ruby
rake oa_angular_setup:create
```  


To Configure any of the settings run: 
```ruby rails g oa_angular_setup:install ```
or create a new initializer and add the following
```ruby
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
```

## Contributing

Bug reports and pull requests can be made on GitHub at https://github.com/openarcllc/oa_angular_setup.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

