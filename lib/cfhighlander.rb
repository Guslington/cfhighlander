require 'thor'
require 'rubygems'
require 'aws-sdk-core'
require 'cfhighlander/version'
require 'cfhighlander/compiler'
require 'cfhighlander/factory/component'
require 'cfhighlander/publisher'
require 'cfhighlander/validator'
require 'cfhighlander/tests'
require 'cfhighlander/util/aws'
require 'cfhighlander/builder'

module Cfhighlander
  class Cli < Thor

    package_name "cfhighlander"

    map %w[--version -v] => :__print_version
    desc "--version, -v", "print the version"
    def __print_version
      puts Cfhighlander::VERSION
    end

    if ENV['CFHIGHLANDER_WORKDIR'].nil?
      ENV['CFHIGHLANDER_WORKDIR'] = Dir.pwd
    end

    if ENV['HIGHLANDER_WORKDIR'].nil?
      ENV['HIGHLANDER_WORKDIR'] = Dir.pwd
    end

    Aws.config[:retry_limit] = ENV.has_key?('CFHIGHLANDER_AWS_RETRY_LIMIT') ? ENV['CFHIGHLANDER_AWS_RETRY_LIMIT'].to_i : 10

    desc 'configcompile component[@version]', 'Compile Highlander components configuration'

    def configcompile(template_name)

      # find and load component
      component_loader = Cfhighlander::Factory::Component.new
      component = component_loader.loadComponentFromTemplate(template_name)
      component.load

      # compile cfndsl template
      component_compiler = Cfhighlander::Compiler::ComponentCompiler.new(component)
      component_compiler.writeConfig(true)
    end

    desc 'dslcompile component[@version]', 'Compile Highlander component configuration and create cfndsl templates'
    method_option :version, :type => :string, :required => false, :default => nil, :aliases => '-v',
        :desc => 'Version to compile by which subcomponents are referenced'
    method_option :dstbucket, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 bucket'
    method_option :dstprefix, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 prefix'
    method_option :format, :type => :string, :required => true, :default => 'yaml', :aliases => "-f",
        :enum => %w(yaml json), :desc => 'CloudFormation templates output format'
    method_option :quiet, :type => :boolean, :default => false, :aliases => '-q',
        :desc => 'Silently agree on user prompts (e.g. Package lambda command)'

    def dslcompile(component_name)
      component = CfHighlander::Builder.new(options, component_name)

      # compile cfndsl template
      component_compiler = Cfhighlander::Compiler::ComponentCompiler.new(component)
      component_compiler.silent_mode = options[:quiet]
      out_format = options[:format]
      component_compiler.compileCfnDsl out_format
    end


    desc 'cfcompile component[@version]', 'Compile Highlander component to CloudFormation templates'
    method_option :version, :type => :string, :required => false, :default => nil, :aliases => '-v',
        :desc => 'Version to compile by which subcomponents are referenced'
    method_option :dstbucket, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 bucket'
    method_option :dstprefix, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 prefix'
    method_option :format, :type => :string, :required => true, :default => 'yaml', :aliases => "-f",
        :enum => %w(yaml json), :desc => 'CloudFormation templates output format'
    method_option :validate, :type => :boolean, :default => false,
        :desc => 'Optionally validate template'
    method_option :quiet, :type => :boolean, :default => false, :aliases => '-q',
        :desc => 'Silently agree on user prompts (e.g. Package lambda command)'

    def cfcompile(component_name = nil, autogenerate_dist = false)

      if component_name.nil?
        candidates = Dir["*.cfhighlander.rb"]
        if candidates.size == 0
          self.help('cfcompile')
          exit -1
        else
          component_name = candidates[0].gsub('.cfhighlander.rb','')
        end
      end

      builder = Cfhighlander::Builder.new(options, component_name)
      builder.compile_component

    end

    desc 'cfpublish component[@version]', 'Publish CloudFormation template for component,
              and it\' referenced subcomponents'
    method_option :version, :type => :string, :required => false, :default => nil, :aliases => '-v',
        :desc => 'Version to compile by which subcomponents are referenced'
    method_option :dstbucket, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 bucket'
    method_option :dstprefix, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 prefix'
    method_option :format, :type => :string, :required => true, :default => 'yaml', :aliases => "-f",
        :enum => %w(yaml json), :desc => 'CloudFormation templates output format'
    method_option :validate, :type => :boolean, :default => false,
        :desc => 'Optionally validate template'
    method_option :quiet, :type => :boolean, :default => false, :aliases => '-q',
        :desc => 'Silently agree on user prompts (e.g. Package lambda command)'

    def cfpublish(component_name)
      compiler = cfcompile(component_name, true)
      publisher = Cfhighlander::Publisher::ComponentPublisher.new(compiler.component, false, options[:format])
      publisher.publishFiles(compiler.cfn_template_paths + compiler.lambda_src_paths)

      puts "\n\nUse following url to launch CloudFormation stack\n\n#{publisher.getLaunchStackUrl}\n\n"
      puts "\n\nUse following template url to update the stack\n\n#{publisher.getTemplateUrl}\n\n"

    end


    desc 'publish component[@version] [-v published_version]', 'Publish CloudFormation template for component,
              and it\'s referenced subcomponents'
    method_option :dstbucket, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 bucket'
    method_option :dstprefix, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 prefix'
    method_option :version, :type => :string, :required => false, :default => nil, :aliases => '-v',
        :desc => 'Distribution component version, defaults to latest'

    def publish(template_name)
      component_version = options[:version]
      distribution_bucket = options[:dstbucket]
      distribution_prefix = options[:dstprefix]

      # find and load component
      component_loader = Cfhighlander::Factory::Component.new
      component = component_loader.loadComponentFromTemplate(template_name)
      component.version = component_version
      component.distribution_bucket = distribution_bucket unless distribution_bucket.nil?
      component.distribution_prefix = distribution_prefix unless distribution_prefix.nil?
      component.load

      publisher = Cfhighlander::Publisher::ComponentPublisher.new(component, true, 'yaml')
      publisher.publishComponent
    end

    desc 'cftest component[@version]', 'Test Highlander component with test case config'
    method_option :directory, :type => :string, :required => false, :default => 'tests', :aliases => "-d",
        :desc => 'Tests directory'
    method_option :tests, :type => :array, :required => false, :aliases => "-t",
        :desc => 'Point to specific test files using the relative path'
    method_option :dstbucket, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 bucket'
    method_option :dstprefix, :type => :string, :required => false, :default => nil,
        :desc => 'Distribution S3 prefix'
    method_option :format, :type => :string, :required => true, :default => 'yaml', :aliases => "-f",
        :enum => %w(yaml json), :desc => 'CloudFormation templates output format'
    method_option :validate, :type => :boolean, :default => true,
        :desc => 'Optionally validate template'
    method_option :quiet, :type => :boolean, :default => true, :aliases => '-q',
        :desc => 'Silently agree on user prompts (e.g. Package lambda command)'
    method_option :report, :type => :string, :aliases => '-r', :enum => ['json','xml'],
        :desc => 'report output format in reports directory'

    def cftest(component_name = nil, autogenerate_dist = false)

      tests_start = Time.now

      if component_name.nil?
        candidates = Dir["*.cfhighlander.rb"]
        if candidates.size == 0
          self.help('cftest')
          exit -1
        else
          component_name = candidates[0].gsub('.cfhighlander.rb','')
        end
      end

      tests = CfHighlander::Tests.new(component_name,options)
      tests.timestamp = Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')
      tests.get_cases

      tests.cases.each do |test|
        test_name = test[:metadata]['name']
        component = Cfhighlander.build_component(options, component_name, test[:config])
        failure = false

        if component.highlander_dsl.distribution_bucket.nil? or component.highlander_dsl.distribution_prefix.nil?
          component.distribution_bucket="#{Cfhighlander::Util::AwsHelper.aws_account_id()}.#{Cfhighlander::Util::AwsHelper.aws_current_region()}.cfhighlander.templates" if component.distribution_bucket.nil?
          component.distribution_prefix="published-templates/#{component.name}" if component.distribution_prefix.nil?
          puts "INFO: Reloading component, as auto-generated distribution settings  are being applied..."
          component.load
        end if autogenerate_dist

        # compile cloud formation
        component_compiler = Cfhighlander::Compiler::ComponentCompiler.new(component)
        component_compiler.cfn_output_location = "#{ENV['CFHIGHLANDER_WORKDIR']}/out/tests/#{test_name.gsub(' ','_')}"
        component_compiler.silent_mode = options[:quiet]
        out_format = options[:format]

        start = Time.now
        begin
          component_compiler.compileCloudFormation out_format
        rescue => e
          failure = {message: e.message, type: 'Cfhighlander::Compiler::ComponentCompiler'}
        end
        finish = Time.now

        tests.report << {
          name: test_name,
          test: test[:file],
          type: 'compile',
          failure: failure,
          time: (finish - start).to_s
        }
        next if failure

        if options[:validate]
          start = Time.now
          begin
            component_validator = Cfhighlander::Cloudformation::Validator.new(component)
            component_validator.validate(component_compiler.cfn_template_paths, out_format)
          rescue Aws::CloudFormation::Errors::ValidationError => e
            failure = {message: e.message, type: 'Cfhighlander::Cloudformation::Validator'}
          end
          finish = Time.now
        end

        tests.report << {
          name: test_name,
          test: test[:file],
          type: 'Validation',
          failure: failure,
          time: (finish - start).to_s
        }

        component_compiler
      end

      tests_finish = Time.now
      tests.time = (tests_finish - tests_start)

      tests.generate_report(options[:report]) if options[:report]
      tests.print_results
      exit tests.exit_code

    end

  end

end
