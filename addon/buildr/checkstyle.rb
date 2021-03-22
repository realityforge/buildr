# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr
  # Provides the <code>checkstyle:html</code> and <code>checkstyle:xml</code> tasks.
  # Require explicitly using <code>require "buildr/checkstyle"</code>.
  module Checkstyle

    class << self

      # The specs for requirements
      def dependencies
        version = '8.40'
        spec = "com.puppycrawl.tools:checkstyle-all:jar:#{version}"
        Buildr.download(Buildr.artifact(spec) => "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-#{version}/checkstyle-#{version}-all.jar")
        [spec]
      end

      def checkstyle(configuration_file, format, output_file, source_paths, options = {})
        dependencies = self.dependencies + (options[:dependencies] || [])
        cp = Buildr.artifacts(dependencies).each { |a| a.invoke if a.respond_to?(:invoke) }.map(&:to_s)

        args = []
        if options[:properties_file]
          args << '-p'
          args << options[:properties_file]
        end
        args << '-c'
        args << configuration_file
        args << '-f'
        args << format
        args << '-o'
        args << output_file
        args += source_paths.select { |p| File.exist?(p) }

        begin
          Java::Commands.java 'com.puppycrawl.tools.checkstyle.Main', *(args + [{:classpath => cp, :properties => options[:properties], :java_args => options[:java_args]}])
        rescue Exception => e
          raise e if options[:fail_on_error]
        end
      end
    end

    class Config

      attr_writer :enabled

      def enabled?
        @enabled.nil? ? (File.exist?(self.configuration_file) || !self.configuration_artifact.nil?) : !!@enabled
      end

      def html_enabled?
        File.exist?(self.style_file)
      end

      attr_writer :config_directory

      def config_directory
        @config_directory || project._(:source, :main, :etc, :checkstyle)
      end

      attr_writer :report_dir

      def report_dir
        @report_dir || project._(:reports, :checkstyle)
      end

      attr_writer :configuration_file

      def configuration_file=(configuration_file)
        raise 'Configuration artifact already specified' if @configuration_artifact
        @configuration_file = configuration_file
      end

      def configuration_file
        if @configuration_file
          return @configuration_file
        elsif @configuration_artifact.nil?
          "#{self.config_directory}/checks.xml"
        else
          a = Buildr.artifact(@configuration_artifact)
          a.invoke
          a.to_s
        end
      end

      def configuration_artifact=(configuration_artifact)
        raise 'Configuration file already specified' if @configuration_file
        @configuration_artifact = configuration_artifact
      end

      def configuration_artifact
        @configuration_artifact
      end

      attr_writer :fail_on_error

      def fail_on_error?
        @fail_on_error.nil? ? false : @fail_on_error
      end

      attr_writer :format

      def format
        @format || 'xml'
      end

      attr_writer :xml_output_file

      def xml_output_file
        @xml_output_file || "#{self.report_dir}/checkstyle.xml"
      end

      attr_writer :html_output_file

      def html_output_file
        @html_output_file || "#{self.report_dir}/checkstyle.html"
      end

      attr_writer :style_file

      def style_file
        unless @style_file
          project_xsl = "#{self.config_directory}/checkstyle-report.xsl"
          if File.exist?(project_xsl)
            @style_file = project_xsl
          else
            @style_file = "#{File.dirname(__FILE__)}/checkstyle-report.xsl"
          end
        end
        @style_file
      end

      attr_writer :suppressions_file

      def suppressions_file
        @suppressions_file || "#{self.config_directory}/suppressions.xml"
      end

      attr_writer :import_control_file

      def import_control_file
        @import_control_file || "#{self.config_directory}/import-control.xml"
      end

      def properties
        unless @properties
          @properties = {:basedir => self.project.base_dir}
          @properties['checkstyle.suppressions.file'] = self.suppressions_file if File.exist?(self.suppressions_file)
          @properties['checkstyle.import-control.file'] = self.import_control_file if File.exist?(self.import_control_file)
        end
        @properties
      end

      def source_paths
        @source_paths ||= [self.project.compile.sources, self.project.test.compile.sources]
      end

      def extra_dependencies
        @extra_dependencies ||= []
      end

      # An array of additional java_args
      attr_writer :java_args

      def java_args
        @java_args ||= []
      end

      # An array of additional projects to scan for main and test sources
      attr_writer :additional_project_names

      def additional_project_names
        @additional_project_names ||= []
      end

      def complete_source_paths
        paths = self.source_paths.dup

        self.additional_project_names.each do |project_name|
          p = self.project.project(project_name)
          paths << [p.compile.sources, p.test.compile.sources].flatten.compact
        end

        paths.flatten.compact
      end

      protected

      def initialize(project)
        @project = project
      end

      attr_reader :project

    end

    module ProjectExtension
      include Extension

      def checkstyle
        @checkstyle ||= Buildr::Checkstyle::Config.new(project)
      end

      after_define do |project|
        if project.checkstyle.enabled?
          desc 'Generate checkstyle xml report.'
          project.task('checkstyle:xml') do
            puts 'Checkstyle: Analyzing source code...'
            mkdir_p File.dirname(project.checkstyle.xml_output_file)
            source_paths = project.checkstyle.complete_source_paths.select{|p| !p.start_with?(project._(:target, :generated).to_s)}
            source_paths = source_paths.collect{|p|::Buildr::Util.relative_path(File.expand_path(p.to_s), project.base_dir)}
            Buildr::Checkstyle.checkstyle(project.checkstyle.configuration_file,
                                          project.checkstyle.format,
                                          project.checkstyle.xml_output_file,
                                          source_paths,
                                          :properties => project.checkstyle.properties,
                                          :java_args => project.checkstyle.java_args,
                                          :fail_on_error => project.checkstyle.fail_on_error?,
                                          :dependencies => project.checkstyle.extra_dependencies.dup.flatten.compact)
          end

          if project.checkstyle.html_enabled?
            xml_task = project.task('checkstyle:xml')
            desc 'Generate checkstyle html report.'
            project.task('checkstyle:html' => xml_task) do
              puts 'Checkstyle: Generating report'
              mkdir_p File.dirname(project.checkstyle.html_output_file)
              args = ['-IN', project.checkstyle.xml_output_file, '-XSL', project.checkstyle.style_file, '-OUT', project.checkstyle.html_output_file]
              classpath = Buildr.artifacts(%w(xalan:xalan:jar:2.7.2 xalan:serializer:jar:2.7.2 xml-apis:xml-apis:jar:1.3.04))
              Java::Commands.java 'org.apache.xalan.xslt.Process', *(args + [{ :classpath => classpath }])
            end
          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::Checkstyle::ProjectExtension
end
