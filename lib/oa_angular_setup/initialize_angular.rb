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

  def test
    puts "in app"
    puts @app_name
  end

  def update
    mechanize = Mechanize.new
    page = mechanize.get(@url)
    body = JSON.parse(page.body)

    body["apis"].each do |api|
      model = api["path"].split('.')[0]
      api_page = mechanize.get(@url + model)
      api_body = JSON.parse(api_page.body)

      update_factory(api_body["apis"], model, @factory_name) if @create_factories
      update_controllers(api_body["apis"], model, @app_name) if @create_controllers
      # write_app_js(api_body["apis"], model, app_js_file) if @create_app_js 

      write_backups
    end
  end

  def write_backups
    if @create_factories
      Dir.mkdir("#{@destination}factories_backups/") unless File.exists?("#{@destination}factories_backups/")
      FileUtils.cp_r "#{@destination}factories/.", "#{@destination}factories_backups/"
    end
    if @create_factories
      Dir.mkdir("#{@destination}controllers_backups/") unless File.exists?("#{@destination}controllers_backups/")
      FileUtils.cp_r "#{@destination}controllers/.", "#{@destination}controllers_backups/"
    end
  end

  def run
    Dir.mkdir("#{@destination}") unless File.exists?("#{@destination}")
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

  def update_factory(apis, model, name)
    Dir.mkdir("#{@destination}factories") unless File.exists?("#{@destination}factories")

    fh1 = name + ".factory('"
    fh2 = "', ['$resource', function($resource){\n"
    fname = "#{@destination}factories/" + model.gsub("/","") + "_factory.js" 

    backup_file = File.open("#{@destination}factories_backups/" + model.gsub("/","") + "_factory.js", 'r')
    backup_contents = backup_file.read.split("\n")
    backup_file.close
    file = File.open(fname, 'r')
    file_contents = file.read.split("\n")
    file.close

    edited_lines = []
    edited_methods = []
    edited_lines.push(fh1 + model.gsub("/","").chomp('s').capitalize + fh2)
    edited_lines.push("  return $resource('api/v1" + model + "/:id/:action', {}, { \n")
    file_contents.each_with_index do |line, index|
      next if(line.match(/^\/\//i) || backup_contents.include?(line))
      edited_lines.push(file_contents[(index-1)]+"\n")   
      edited_lines.push(line+"\n")
      method = line.split(":")[0]
      edited_methods.push(method)
    end

    apis.each do |endpoint|
      endpoint["operations"].each do |op|

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

        if( !file_contents.include?(string) && backup_contents.include?(string) )
          next
        end
        next if(edited_methods.include?(string.split(":")[0]))
        edited_lines.push("    // #{op['summary']} \n")
        edited_lines.push(string)


        if op == endpoint["operations"].last && endpoint == apis.last
          edited_lines.push("\n")
        else
          edited_lines.push(",\n")
        end
      end
    end
    edited_lines.push("  });\n")
    edited_lines.push("}]);\n")

    outfile = File.open(fname, 'w')
    outfile.write(edited_lines.join)
    outfile.close
  end

  def update_controllers(apis, model_name, app_name)
    Dir.mkdir("#{@destination}controllers") unless File.exists?("#{@destination}controllers") 
    output = []
    model = model_name.delete('/')
    service = model.chomp('s').capitalize

    backup_file = File.open("#{@destination}controllers_backups/#{model}_controllers.js", 'r')
    backup_contents = backup_file.read
    backup_file.close
    file = File.open("#{@destination}controllers/#{model}_controllers.js", 'r')
    file_contents = file.read
    file.close

    controllers = file_contents.scan(/angular.module.*?}\]\);/im)
    backup_controllers = backup_contents.scan(/angular.module.*?}\]\);/im)

    edited_controller_titles = []
    controllers.each_with_index do |controller, index|
      next if(backup_controllers.include?(controller))
      output.push(controller+" \n \n")
      controller_title = controller.match(/.controller\('(.*?)'/im)[1]
      edited_controller_titles.push(controller_title)
    end

    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        string = ""
        controller_title = ""
        ep_path = endpoint["path"].split('/')
        case op["method"]
        when /GET/
          if ep_path[4].nil?
            if endpoint["path"].include?("id")
              controller_title = "#{model.capitalize}IndexCtrl"
              string += "angular.module('#{@app_name}').controller('#{controller_title}', ['$scope', '#{service}', function ($scope, #{service}) { \n"
              string += "  $scope.#{model} = #{service}.query(); \n"
              string += "}]); \n"
              string += " \n"
            else
              controller_title = "#{model.capitalize}ShowCtrl"
              string += "angular.module('#{@app_name}').controller('#{controller_title}', ['$scope', '$routeParams', '#{service}', function ($scope, $routeParams, #{service}) { \n"
              string += "  $scope.id = $routeParams.id; \n"
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

        output.push(string) unless edited_controller_titles.include?(controller_title)
      end
    end
    outfile = File.open("#{@destination}controllers/#{model}_controllers.js", 'w')
    outfile.write(output.join)
    outfile.close
  end

  def write_factories(apis, model, name)
    Dir.mkdir("#{@destination}factories") unless File.exists?("#{@destination}factories")

    fh1 = name + ".factory('"
    fh2 = "', ['$resource', function($resource){\n"

    fname = "#{@destination}factories/" + model.gsub("/","") + "_factory.js" 
    outfile = File.open(fname, 'w')
    outfile.write(fh1 + model.gsub("/","").chomp('s').capitalize + fh2)
    outfile.write("  return $resource('api/v1" + model + "/:id/:action', {}, { \n")
    
    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        outfile.write("    // #{op['summary']} \n")
        ep_path = endpoint["path"].split('/')
        case op["method"]
        when /GET/
          output_to_angular(outfile, op["method"], endpoint["path"])
        when /PUT/
          output_to_angular(outfile, op["method"], endpoint["path"])
        when /POST/
          outfile.write("    create: {method:'POST'}")
        when /DELETE/
          outfile.write("    destroy: {method:'DELETE'}")
        end
        if op == endpoint["operations"].last && endpoint == apis.last
          outfile.write("\n")
        else
          outfile.write(",\n")
        end
      end
    end
    outfile.write("  });\n")
    outfile.write("}]);\n")
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
    service = model.chomp('s').capitalize
    outfile = File.open("#{@destination}controllers/#{model}_controllers.js", 'w')
    apis.each do |endpoint|
      endpoint["operations"].each do |op|
        case op["method"]
        when /GET/
          ep_path = endpoint["path"].split('/')
          if ep_path[4].nil?
            if endpoint["path"].include?("id")
              outfile.write("angular.module('#{@app_name}').controller('#{model.capitalize}IndexCtrl', ['$scope', '#{service}', function ($scope, #{service}) { \n")
              outfile.write("  $scope.#{model} = #{service}.query(); \n")
              outfile.write("}]); \n")
              outfile.write(" \n")
            else
              outfile.write("angular.module('#{@app_name}').controller('#{model.capitalize}ShowCtrl', ['$scope', '$routeParams', '#{service}', function ($scope, $routeParams, #{service}) { \n")
              outfile.write("  $scope.id = $routeParams.id; \n");
              outfile.write("}]); \n")
              outfile.write(" \n")
            end
          end
        when /PUT/
          ep_path = endpoint["path"].split('/')
          if ep_path[4].nil?
            outfile.write("angular.module('#{@app_name}').controller('#{model.capitalize}EditCtrl', ['$scope', '$routeParams', '#{service}', function ($scope, $routeParams, #{service}) { \n")
            outfile.write("  $scope.id = $routeParams.id; \n");
            outfile.write("}]); \n")
            outfile.write(" \n")
          end
        when /POST/
          outfile.write("angular.module('#{@app_name}').controller('#{model.capitalize}NewCtrl', ['$scope', '#{service}', function ($scope, #{service}) { \n")
          outfile.write("}]); \n")
          outfile.write(" \n")
        end
      end
    end
    outfile.close
  end
end

