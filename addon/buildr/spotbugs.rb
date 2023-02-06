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
  # Provides the <code>spotbugs:html</code> and <code>spotbugs:xml</code> tasks.
  # Require explicitly using <code>require "buildr/spotbugs"</code>.
  module Spotbugs

    class << self

      # The specs for requirements
      def dependencies
        %w(
          commons-codec:commons-codec:jar:1.15
          com.github.spotbugs:spotbugs:jar:4.7.3
          com.github.spotbugs:spotbugs-annotations:jar:4.7.3
          com.google.code.findbugs:jsr305:jar:3.0.2
          com.google.code.gson:gson:jar:2.9.1
          net.jcip:jcip-annotations:jar:1.0
          org.apache.bcel:bcel:jar:6.5.0
          org.apache.commons:commons-lang3:jar:3.12.0
          org.apache.commons:commons-text:jar:1.10.0
          org.apache.httpcomponents.client5:httpclient5:jar:5.1.3
          org.apache.httpcomponents.core5:httpcore5:jar:5.1.3
          org.apache.httpcomponents.core5:httpcore5-h2:jar:5.1.3
          org.dom4j:dom4j:jar:2.1.3
          org.json:json:jar:20201115
          org.ow2.asm:asm:jar:9.4
          org.ow2.asm:asm-analysis:jar:9.4
          org.ow2.asm:asm-tree:jar:9.4
          org.ow2.asm:asm-commons:jar:9.4
          org.ow2.asm:asm-util:jar:9.4
          org.slf4j:slf4j-api:jar:2.0.0
          org.xmlresolver:xmlresolver:jar:4.4.3
          jaxen:jaxen:jar:1.2.0
          net.sf.saxon:Saxon-HE:jar:11.4
          xml-apis:xml-apis:jar:1.4.01
        )
      end

      def fb_contrib_dependencies
        %w(com.mebigfatguy.fb-contrib:fb-contrib:jar:7.4.2.sb)
      end

      def spotbugs(output_file, source_paths, analyze_paths, options = {})
        plugins = self.fb_contrib_dependencies
        Buildr.artifacts(self.dependencies).each { |a| a.invoke if a.respond_to?(:invoke) }

        args = []
        args << '-textui'
        packages_to_analyze = options[:packages_to_analyze] || []
        if packages_to_analyze.size > 0
          args << '-onlyAnalyze' << (packages_to_analyze.collect{|p| "#{p}.-"}.join(',') + ':')
        end
        args << '-effort:max'
        args << '-medium'
        args << ('html' == options[:output] ? '-html' : '-xml:withMessages')
        args << '-output' << output_file
        args << '-sourcepath' << source_paths.map(&:to_s).join(File::PATH_SEPARATOR)
        args << '-pluginList' << Buildr.artifacts(plugins).map(&:to_s).join(File::PATH_SEPARATOR)

        extra_dependencies = (options[:extra_dependencies] || []) + plugins
        if 0 != extra_dependencies.size
          args << '-auxclasspath' << Buildr.artifacts(extra_dependencies).each { |a| a.invoke if a.respond_to?(:invoke) }.map(&:to_s).join(File::PATH_SEPARATOR)
        end
        if options[:exclude_filter]
          args << '-exclude' << options[:exclude_filter]
        end

        analyze_paths.each do |dep|
          a = dep.is_a?(String) ? file(dep) : dep
          a.invoke
          args << a.to_s
        end

        mkdir_p File.dirname(output_file)

        begin
          Java::Commands.java 'edu.umd.cs.findbugs.LaunchAppropriateUI', *(args + [{:classpath => Buildr.artifacts(dependencies), :properties => options[:properties], :java_args => options[:java_args]}])
        rescue Exception => e
          puts e
          raise e if options[:fail_on_error]
        end
      end
    end

    class Config

      attr_accessor :enabled

      def enabled?
        !!@enabled
      end

      attr_writer :config_directory

      def config_directory
        @config_directory || project._(:source, :main, :etc, :spotbugs)
      end

      attr_writer :report_dir

      def report_dir
        @report_dir || project._(:reports, :spotbugs)
      end

      attr_writer :fail_on_error

      def fail_on_error?
        @fail_on_error.nil? ? false : @fail_on_error
      end

      attr_writer :xml_output_file

      def xml_output_file
        @xml_output_file || "#{self.report_dir}/spotbugs.xml"
      end

      attr_writer :html_output_file

      def html_output_file
        @html_output_file || "#{self.report_dir}/spotbugs.html"
      end

      attr_writer :filter_file

      def filter_file
        @filter_file || "#{self.config_directory}/filter.xml"
      end

      def properties
        @properties ||= {}
      end

      attr_writer :java_args

      def java_args
        @java_args || '-server -Xss1m -Xmx1.4G -Duser.language=en -Duser.region=EN'
      end

      def packages_to_analyze
        @packages_to_analyze ||= [self.project.java_package_name]
      end

      def source_paths
        @source_paths ||= [self.project.compile.sources, self.project.test.compile.sources].flatten.compact
      end

      def analyze_paths
        @analyze_path ||= [self.project.compile.target]
      end

      def extra_dependencies
        @extra_dependencies ||= [self.project.compile.dependencies, self.project.test.compile.dependencies].flatten.compact
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

      def complete_analyze_paths
        paths = self.analyze_paths.dup

        self.additional_project_names.each do |project_name|
          paths << self.project.project(project_name).compile.target
        end

        paths.flatten.compact
      end

      def complete_extra_dependencies
        deps = self.extra_dependencies.dup

        self.additional_project_names.each do |project_name|
          p = self.project.project(project_name)
          deps << [p.compile.dependencies, p.test.compile.dependencies].flatten.compact
        end

        deps.flatten.compact
      end

      protected

      def initialize(project)
        @project = project
      end

      attr_reader :project
    end

    module ProjectExtension
      include Extension

      def spotbugs
        @spotbugs ||= Buildr::Spotbugs::Config.new(project)
      end

      after_define do |project|
        if project.spotbugs.enabled?
          desc 'Generate spotbugs xml report.'
          project.task('spotbugs:xml') do
            puts 'Spotbugs: Analyzing source code...'
            options =
              {
                :packages_to_analyze => project.spotbugs.packages_to_analyze,
                :properties => project.spotbugs.properties,
                :fail_on_error => project.spotbugs.fail_on_error?,
                :extra_dependencies => project.spotbugs.complete_extra_dependencies
              }
            options[:exclude_filter] = project.spotbugs.filter_file if File.exist?(project.spotbugs.filter_file)
            options[:output] = 'xml:withMessages'

            Buildr::Spotbugs.spotbugs(project.spotbugs.xml_output_file,
                                      project.spotbugs.complete_source_paths,
                                      project.spotbugs.complete_analyze_paths,
                                      options)
          end

          desc 'Generate spotbugs html report.'
          project.task('spotbugs:html') do
            puts 'Spotbugs: Analyzing source code...'
            options =
              {
                :packages_to_analyze => project.spotbugs.packages_to_analyze,
                :properties => project.spotbugs.properties,
                :fail_on_error => project.spotbugs.fail_on_error?,
                :extra_dependencies => project.spotbugs.complete_extra_dependencies
              }
            options[:exclude_filter] = project.spotbugs.filter_file if File.exist?(project.spotbugs.filter_file)
            options[:output] = 'html'

            Buildr::Spotbugs.spotbugs(project.spotbugs.html_output_file,
                                      project.spotbugs.complete_source_paths,
                                      project.spotbugs.complete_analyze_paths,
                                      options)
          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::Spotbugs::ProjectExtension
end
