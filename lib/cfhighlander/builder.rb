require 'cfhighlander/factory/component'
require 'cfhighlander/util/aws'
require 'cfhighlander/compiler'
require 'cfhighlander/validator'

module Cfhighlander
  class Builder

    def initialize(options, template_name, config=nil)
      @template_name = template_name
      @config = config
      @component_version = options[:version]
      @distribution_bucket = options[:dstbucket]
      @distribution_prefix = options[:dstprefix]
      @quiet = options[:quiet]
      @format = options[:format]
      @validate = options[:validate]
    end

    def build_component()
      # find and load component
      component_loader = Cfhighlander::Factory::Component.new
      component = component_loader.loadComponentFromTemplate(@template_name)
      component.version = @component_version unless @component_version.nil?
      component.config = @config unless @config.nil?
      component.distribution_bucket = @distribution_bucket unless @distribution_bucket.nil?
      component.distribution_prefix = @distribution_prefix unless @distribution_prefix.nil?
      component.load
      return component
    end

    def compile_component()

      component = build_component()

      if component.highlander_dsl.distribution_bucket.nil? or component.highlander_dsl.distribution_prefix.nil?
        component.distribution_bucket="#{Cfhighlander::Util::AwsHelper.aws_account_id()}.#{Cfhighlander::Util::AwsHelper.aws_current_region()}.cfhighlander.templates" if component.distribution_bucket.nil?
        component.distribution_prefix="published-templates/#{component.name}" if component.distribution_prefix.nil?
        puts "INFO: Reloading component, as auto-generated distribution settings  are being applied..."
        component.load
      end

      # compile cloud formation
      component_compiler = Cfhighlander::Compiler::ComponentCompiler.new(component)
      component_compiler.silent_mode = @quiet
      component_compiler.compileCloudFormation @format

      if @validate
        component_validator = Cfhighlander::Cloudformation::Validator.new(component)
        component_validator.validate(component_compiler.cfn_template_paths, @format)
      end

      return component_compiler

    end

  end
end
