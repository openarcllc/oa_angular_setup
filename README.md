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
To Configure any of the settings create a new initializer and add 
```ruby

  OaAngularSetup.configure do |config|
    # Set the options to what makes sense for you

    config.app_name = 'App'
    config.create_factories = true 
    config.create_app_js = true 
    config.create_controllers = true
    config.swagger_doc_url = "http://localhost:3000/api/swagger_doc"
    config.destination = "/public/angular/"
  end

```

## Contributing

Bug reports and pull requests can be made on GitHub at https://github.com/markvanarsdale/oa_angular_setup.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

