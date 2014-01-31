require 'motion-require'

unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

vars_yml_filename = "app.yml"
vars_yml_path = "resources/#{vars_yml_filename}"

namespace "config:vars" do
  desc "Generate starter #{vars_yml_filename}, append it to your .gitignore"
  task :init do
    # write out the file
    template_filepath = File.join(File.dirname(File.realdirpath(__FILE__)),
                                  "/motion-config-vars/templates/#{vars_yml_filename}")
    content = File.read template_filepath
    if File.exists? vars_yml_path
      puts "ERROR: file already exists #{vars_yml_path}"
    else
      puts "writing #{vars_yml_path}"
      puts content
      File.open(vars_yml_path, "w") { |file| file.write content }
    end
    # append filepath to project's .gitignore
    if File.exists? '.gitignore'
      File.open('.gitignore', "a") do |file|
        file.puts "\n# Ignore motion-config-vars config file\n#{vars_yml_path}"
      end
    end
  end
end


require 'rake/hooks'

before *%w{ spec
            config
            default
            build build:device build:simulator
            archive archive:distribution } do

  unless File.exists? vars_yml_path
    puts "WARNING: '#{vars_yml_path}' missing. Run 'rake config:vars:init' to generate one."
  else

    # NOTE: RM appears to monitor a project Rakefile's modified-at timestamp,
    # so we force-update it before every build to ensure the build reflects
    # the latest passed-in environment variable(s).
    `touch Rakefile`

    require 'yaml' # TODO: how to exclude from build?
    require 'motion-yaml'

    Motion::Project::App.setup do |app|
      vars_yaml = File.read vars_yml_path
      vars_data = YAML.load vars_yaml

      %w{ configuration_error hashlike_object_configurer }.each do |filename|
        require File.join(File.dirname(__FILE__), "motion-config-vars/embed/#{filename}")
      end
      MotionConfigVars::HashlikeObjectConfigurer.new({
        config_vars_data: vars_data,
        hashlike_object: app.info_plist,
        config_name_for_facet_named: lambda { |facet_name| ENV[facet_name] }
      }).perform!

      # once app.info_plist successfully configured, insert code necessary to
      # configure app's ENV as well.
      Dir.glob(File.join(File.dirname(__FILE__), 'motion-config-vars/embed/*.rb')).each do |file|
        app.files.unshift file
      end

    end

  end

end

