require 'mechanize'
require 'nokogiri'
require 'rails'
class AngularInitializer

  def initialize
    config = OaAngularSetup.configuration
    @app_name = config.app_name
    @factory_name = "#{@app_name}Services"
    @create_factories = config.create_factories
    @create_app_js = config.create_app_js
    @create_controllers = config.create_controllers
    @url = config.swagger_doc_url
    @destination = "#{Rails.root}#{config.destination}"
  end

  def add_angular
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
        new_contents = text.gsub('http://petstore.swagger.io/v2/swagger.json', @url)
        File.open(file_name, "w") {|file| file.puts new_contents }
      end
    end
  end

  def update
    mechanize = Mechanize.new
    page = mechanize.get(@url)
    body = JSON.parse(page.body)
    app_bodies = {}

    body["apis"].each do |api|
      model = api["path"].split('.')[0]
      api_page = mechanize.get(@url + model)
      api_body = JSON.parse(api_page.body)
      app_bodies[model] = api_body["apis"]

      update_factory(api_body["apis"], model, @factory_name) if @create_factories
      update_controllers(api_body["apis"], model, @app_name) if @create_controllers
    end
    update_app_js(app_bodies) if @create_app_js 

    write_backups
  end

  def write_backups
    Dir.mkdir("#{@destination}backups/") unless File.exists?("#{@destination}backups/")
    if @create_factories
      Dir.mkdir("#{@destination}backups/factories/") unless File.exists?("#{@destination}backups/factories/")
      FileUtils.cp_r "#{@destination}factories/.", "#{@destination}backups/factories/"
    end
    if @create_factories
      Dir.mkdir("#{@destination}backups/controllers/") unless File.exists?("#{@destination}backups/controllers/")
      FileUtils.cp_r "#{@destination}controllers/.", "#{@destination}backups/controllers/"
    end
    if @create_app_js
      FileUtils.cp "#{@destination}#{@app_name}.js", "#{@destination}backups/#{@app_name}.js"
    end
  end

  def run
    Dir.mkdir("#{@destination}") unless File.exists?("#{@destination}")
    add_angular
    mechanize = Mechanize.new
    page = mechanize.get(@url)
    body = JSON.parse(page.body)

    if @create_app_js
      app_js_file = File.open("#{@destination}#{@app_name}.js", 'w')
      if @create_factories
        app_js_file.write("var #{@app_name} = angular.module('#{@app_name}', ['ngRoute', '#{@factory_name}']); \n")
      else
        app_js_file.write("var #{@app_name} = angular.module('#{@app_name}', ['ngRoute']); \n")
      end
      app_js_file.write("\n ");
      app_js_file.write("#{@app_name}.config(['$routeProvider', function($routeProvider) { \n");
      app_js_file.write("  $routeProvider.\n")
    end

    body["apis"].each do |api|
      model = api["path"].split('.')[0]
      api_page = mechanize.get(@url + model)
      api_body = JSON.parse(api_page.body)

      write_factories(api_body["apis"], model, @factory_name) if @create_factories
      write_app_js(api_body["apis"], model, app_js_file) if @create_app_js 
      write_controllers(api_body["apis"], model, @app_name) if @create_controllers
    end

    if @create_app_js
      app_js_file.write("    otherwise({ \n")
      app_js_file.write("      redirectTo: '/' \n")
      app_js_file.write("    }); \n")
      app_js_file.write("}]); \n")
      if @create_factories
        app_js_file.write("\n")
        app_js_file.write("var #{@factory_name} = angular.module('#{@factory_name}', ['ngResource']); \n")
      end
      app_js_file.close
    end
    write_backups
  end

  def output_to_angular(outfile_or_string, method, path)
    string = ""
    # assuming only called for PUT and GET methods
    if method == 'GET'
      command = 'show'
    elsif method == 'PUT'
      command = 'update'
    else
      puts "problem. method not GET or PUT"
      return
    end
    if path.include?("id")
      ep_path = path.split('/')
      if ep_path[4].nil?
        string += "    #{command}: {method:'#{method}'}"
      else
        action = ep_path[4].split(".")[0]
        if method == 'GET'
          string += "    #{action}: {method:'#{method}', isArray:true, params:{action:'#{action}'}}"
        else
          string += "    #{action}: {method:'#{method}', params:{action:'#{action}'}}"
        end
      end
    else
      string += "    query: {method:'#{method}', isArray:true}"
    end
    if outfile_or_string.is_a?(File)
      outfile_or_string.write(string)
    else
      return string
    end
  end

  def write_factories(apis, model, name)
    Dir.mkdir("#{@destination}factories") unless File.exists?("#{@destination}factories")

    fh1 = name + ".factory('"
    fh2 = "', ['$resource', function($resource){\n"
    output = []
    fname = "#{@destination}factories/" + model.gsub("/","") + "_factory.js" 
    output_string = fh1 + model.gsub("/","").chomp('s').capitalize + fh2
    output_string += "  return $resource('api/v1" + model + "/:id/:action', {}, { \n"
    
    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        string = write_factory(endpoint, op)
        string = "    // #{op['summary']} \n"+string
        output.push(string)
      end
    end

    output_string += output.join(",\n")
    output_string += "\n  });\n"
    output_string += "}]);\n"

    outfile = File.open(fname, 'w')
    outfile.write(output_string)
    outfile.close
  end

  def write_app_js(apis, model_name, outfile)
    model = model_name.delete('/')
    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        case op["method"]
          when /GET/
            ep_path = endpoint["path"].split('/')
            if ep_path[4].nil?
              if endpoint["path"].include?("id")
                outfile.write("    when('/#{model}/:id', { \n")
                outfile.write("      template@url: '/angular/templates/#{model}/show.html', \n")
                outfile.write("      controller:  '#{model.capitalize}ShowCtrl' \n")
              else
                ctrl = 'index'
                outfile.write("    when('/#{model}', { \n")
                outfile.write("      template@url: '/angular/templates/#{model}/index.html',\n")
                outfile.write("      controller:  '#{model.capitalize}IndexCtrl' \n")
              end
              outfile.write("    }). \n")
            end
          when /PUT/
            ep_path = endpoint["path"].split('/')
            if ep_path[4].nil?
              outfile.write("    when('/#{model}/:id/edit', { \n")
              outfile.write("      template@url: '/angular/templates/#{model}/edit.html', \n")
              outfile.write("      controller:  '#{model.capitalize}EditCtrl' \n")
              outfile.write("    }). \n")
            end
          when /POST/
            outfile.write("    when('/#{model}/new', { \n")
            outfile.write("      template@url: '/angular/templates/#{model}/new.html', \n")
            outfile.write("      controller: '#{model.capitalize}NewCtrl' \n")
            outfile.write("    }). \n")
        end
      end
    end
  end

  def write_controllers(apis, model_name, app_name)
    Dir.mkdir("#{@destination}controllers") unless File.exists?("#{@destination}controllers") 
    model = model_name.delete('/')
    output = []
    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        string,controller_title = write_controller(model, endpoint, op)       
        output.push(string)
      end
    end
    outfile = File.open("#{@destination}controllers/#{model}_controllers.js", 'w')
    outfile.write(output.join)
    outfile.close
  end

  def update_factory(apis, model, name)
    Dir.mkdir("#{@destination}factories") unless File.exists?("#{@destination}factories")

    fh1 = name + ".factory('"
    fh2 = "', ['$resource', function($resource){\n"
    fname = "#{@destination}factories/" + model.gsub("/","") + "_factory.js" 
    # backup_contents = File.read("#{@destination}backups/factories/" + model.gsub("/","") + "_factory.js").split("\n")
    file_contents = File.read(fname)
    file_contents_lines = file_contents.split("\n")
    first_lines = file_contents_lines.shift(2)
    output_string = first_lines.join("\n")+"\n"
    file_contents_lines.pop(2) #drop last two closing lines so they arent added twice
    paths = file_contents.scan(/\n\s*(\w*?):/i).flatten

    output = []
    file_contents_lines.each_with_index do |line, index|
      output.push(line.chomp(","))
    end

    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        string = write_factory(endpoint, op)
        next if output.include?(string)          
        next if(paths.include?(string.split(":")[0]))
        string = "    // #{op['summary']} \n"+string
        output.push(string)
      end
    end

    output_string += output.join(",\n")
    output_string += "\n  });\n"
    output_string += "}]);\n"

    outfile = File.open(fname, 'w')
    outfile.write(output_string)
    outfile.close
  end

  def write_controller(model, endpoint, op)
    string = ""
    controller_title = ""
    service = model.chomp('s').capitalize
    ep_path = endpoint["path"].split('/')
    case op["method"]
    when /GET/
      if ep_path[4].nil?
        if endpoint["path"].include?("id")
          controller_title = "#{model.capitalize}ShowCtrl"
          string += "angular.module('#{@app_name}').controller('#{controller_title}', ['$scope', '$routeParams', '#{service}', function ($scope, $routeParams, #{service}) { \n"
          string += "  $scope.id = $routeParams.id; \n"
          string += "}]); \n"
          string += " \n"
        else
          controller_title = "#{model.capitalize}IndexCtrl"
          string += "angular.module('#{@app_name}').controller('#{controller_title}', ['$scope', '#{service}', function ($scope, #{service}) { \n"
          string += "  $scope.#{model} = #{service}.query(); \n"
          string += "}]); \n"
          string += " \n"
        end
      end
    when /PUT/
      if ep_path[4].nil?
        controller_title = "#{model.capitalize}EditCtrl"
        string += "angular.module('#{@app_name}').controller('#{controller_title}', ['$scope', '$routeParams', '#{service}', function ($scope, $routeParams, #{service}) { \n"
        string += "  $scope.id = $routeParams.id; \n"
        string += "}]); \n"
        string += " \n"
      end
    when /POST/
      controller_title = "#{model.capitalize}NewCtrl"
      string += "angular.module('#{@app_name}').controller('#{controller_title}', ['$scope', '#{service}', function ($scope, #{service}) { \n"
      string += "}]); \n"
      string += " \n"
    end

    return string, controller_title
  end

  def write_factory(endpoint, op)
    string = ""
    case op["method"]
    when /GET/
      string = output_to_angular(string, op["method"], endpoint["path"])
    when /PUT/
      string = output_to_angular(string, op["method"], endpoint["path"])
    when /POST/
      string = "    create: {method:'POST'}"
    when /DELETE/
      string = "    destroy: {method:'DELETE'}"
    end

    return string
  end

  def update_controllers(apis, model_name, app_name)
    Dir.mkdir("#{@destination}controllers") unless File.exists?("#{@destination}controllers") 
    output, edited_controller_titles = [], []
    model = model_name.delete('/')
    file_contents = File.read("#{@destination}controllers/#{model}_controllers.js")
    controller_names = file_contents.scan(/controller\('(.*?)'/im).flatten
    controllers = file_contents.scan(/angular.module.*?}\]\);/im)

    controllers.each do |controller|
      output.push(controller+" \n \n")
    end

    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        string,controller_title = write_controller(model, endpoint, op)       

        output.push(string) unless controller_names.include?(controller_title)
      end
    end
    outfile = File.open("#{@destination}controllers/#{model}_controllers.js", 'w')
    outfile.write(output.join)
    outfile.close
  end

  def update_app_js(apis)
    output, edited_routes = [],[]
    file_contents = File.read("#{@destination}#{@app_name}.js")
    routes = file_contents.scan(/when\(.*?}\)\./im)
    route_paths = file_contents.scan(/when\('(.*?)'/im).flatten

    if @create_app_js
      if @create_factories
        output.push("var #{@app_name} = angular.module('#{@app_name}', ['ngRoute', '#{@factory_name}']); \n")
      else
        output.push("var #{@app_name} = angular.module('#{@app_name}', ['ngRoute']); \n")
      end
      output.push("\n #{@app_name}.config(['$routeProvider', function($routeProvider) { \n  $routeProvider.\n");
    end

    routes.each_with_index do |route, index|
      output.push("    #{route} \n ")
    end

    apis.each do |model_name, model_api|
      model = model_name.delete('/')
      model_api.each do |endpoint|
        endpoint["operations"].each do |op|
          string , route_path = "",""
          case op["method"]
            when /GET/
              ep_path = endpoint["path"].split('/')
              if ep_path[4].nil?
                if endpoint["path"].include?("id")
                  route_path = "/#{model}/:id"
                  string += "    when('#{route_path}', { \n"
                  string += "      template@url: '/angular/templates/#{model}/show.html', \n"
                  string += "      controller:  '#{model.capitalize}ShowCtrl' \n"
                else
                  ctrl = 'index'
                  route_path = "/#{model}"
                  string += "    when('#{route_path}', { \n"
                  string += "      template@url: '/angular/templates/#{model}/index.html',\n"
                  string += "      controller:  '#{model.capitalize}IndexCtrl' \n"
                end
                string += "    }). \n"
              end
            when /PUT/
              ep_path = endpoint["path"].split('/')
              if ep_path[4].nil?
                route_path = "/#{model}/:id/edit"
                string += "    when('#{route_path}', { \n"
                string += "      template@url: '/angular/templates/#{model}/edit.html', \n"
                string += "      controller:  '#{model.capitalize}EditCtrl' \n"
                string += "    }). \n"
              end
            when /POST/
              route_path = "/#{model}/new"
              string += "    when('#{route_path}', { \n"
              string += "      template@url: '/angular/templates/#{model}/new.html', \n"
              string += "      controller: '#{model.capitalize}NewCtrl' \n"
              string += "    }). \n"
          end
          output.push(string) unless route_paths.include?(route_path)
          
        end
      end
    end
    output.push("    otherwise({ \n")
    output.push("      redirectTo: '/' \n")
    output.push("    }); \n")
    output.push("}]); \n")
    if @create_factories
      output.push("\n")
      output.push("var #{@factory_name} = angular.module('#{@factory_name}', ['ngResource']); \n")
    end
    app_js_file = File.open("#{@destination}#{@app_name}.js", 'w')
    app_js_file.write(output.join)
    app_js_file.close
  end

end

