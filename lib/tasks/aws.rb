require "erb"
require "json"
require "fog"
require "fog/aws/cloud_formation"

namespace :drupal do
  AWS_DIR = "#{File.dirname(__FILE__)}/aws"

  directory BUILD_DIR
  
  desc "creates the project's infrastructure in the Amazon cloud"
  task :provision => :settings do
    template_body = contents("#{AWS_DIR}/drupal-stack-template.erb")

    puts "creating aws stack, this might take a while... ".white
    cloud = cloud_formation
    cloud.create_stack(SETTINGS["cloudformation_stack_name"],
                       "TemplateBody" => ERB.new(template_body).result(binding),
                       "Parameters" => { "DrupalSiteAdmin" => "admin",
                                         "DrupalSitePwd" => "admin"})
    stack = nil
    until stack
      sleep 30
      puts "looking for created stack at #{Time.now}...".yellow
      stack = find_stack(cloud)
    end
    puts "your servers have been provisioned successfully".white
  end

  desc "stops all instances and releases all Amazon resources"
  task :shutdown => :settings do
    cloud_formation.delete_stack SETTINGS["cloudformation_stack_name"]
    puts "shutdown command successful".green
  end

  task :settings do
    SETTINGS = YAML::parse(open("conf/settings.yaml")).transform
  end

  def cloud_formation
    Fog::AWS::CloudFormation.new(:aws_access_key_id => SETTINGS["aws_access_key"],
                                 :aws_secret_access_key => SETTINGS["aws_secret_access_key"],
                                 :region => "ap-southeast-1")
  end

  def find_stack(cloud)
    cloud.describe_stacks.body["Stacks"].find do |stack|
      stack["StackName"] == SETTINGS["cloudformation_stack_name"] && stack["StackStatus"] == "CREATE_COMPLETE"
    end
  end

  def contents(file)
    contents = ""
    File.open(file) { |f| contents << f.read }
    contents
  end
end
