# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with this
# work for additional information regarding copyright ownership. The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr
  # Initial support for JaCoCo coverage reports.
  module JaCoCo
    class << self
      def agent_spec
        %w(org.jacoco:org.jacoco.agent:jar:runtime:0.8.6)
      end

      def dependencies
        %w[
          args4j:args4j:jar:2.0.28
          org.jacoco:org.jacoco.report:jar:0.8.6
          org.jacoco:org.jacoco.core:jar:0.8.6
          org.jacoco:org.jacoco.cli:jar:0.8.6
          org.ow2.asm:asm:jar:8.0.1
          org.ow2.asm:asm-commons:jar:8.0.1
          org.ow2.asm:asm-tree:jar:8.0.1
          org.ow2.asm:asm-analysis:jar:8.0.1
          org.ow2.asm:asm-util:jar:8.0.1
        ]
      end

      def jacoco_report(execution_files, class_paths, source_paths, options = {})

        xml_output_file = options[:xml_output_file]
        csv_output_file = options[:csv_output_file]
        html_output_directory = options[:html_output_directory]

        Buildr.artifacts(self.dependencies).each { |a| a.invoke if a.respond_to?(:invoke) }

        args = []
        args << 'report'
        args += execution_files
        class_paths.each do |class_path|
          args << '--classfiles' << class_path
        end
        args << '--csv' << csv_output_file if csv_output_file
        args << '--encoding' << 'UTF-8'
        args << '--html' << html_output_directory if html_output_directory
        source_paths.each do |source_path|
          args << '--sourcefiles' << source_path
        end
        args << '--xml' << xml_output_file if xml_output_file

        Java::Commands.java 'org.jacoco.cli.internal.Main', *(args + [{ :classpath => Buildr.artifacts(self.dependencies), :properties => options[:properties], :java_args => options[:java_args] }])
      end
    end

    class Config
      attr_writer :enabled

      def enabled?
        @enabled.nil? ? true : @enabled
      end

      attr_accessor :destfile

      attr_writer :output

      def output
        @output ||= 'file'
      end

      attr_accessor :sessionid
      attr_accessor :address
      attr_accessor :port
      attr_accessor :classdumpdir
      attr_accessor :dumponexit
      attr_accessor :append
      attr_accessor :exclclassloader

      def includes
        @includes ||= []
      end

      def excludes
        @excludes ||= []
      end

      protected

      def initialize(destfile)
        @destfile = destfile
      end
    end

    module ProjectExtension
      include Extension

      def jacoco
        @jacoco ||= Buildr::JaCoCo::Config.new(project._(:reports, :jacoco, 'jacoco.cov'))
      end

      after_define do |project|
        unless project.test.compile.target.nil? || !project.jacoco.enabled?
          project.test.setup do
            agent_jar = Buildr.artifacts(Buildr::JaCoCo.agent_spec).each(&:invoke).map(&:to_s).join('')
            options = []
            %w(destfile append exclclassloader sessionid dumponexit output address port classdumpdir).each do |option|
              value = project.jacoco.send(option.to_sym)
              options << "#{option}=#{value}" unless value.nil?
            end
            options << "includes=#{project.jacoco.includes.join(':')}" unless project.jacoco.includes.empty?
            options << "excludes=#{project.jacoco.excludes.join(':')}" unless project.jacoco.excludes.empty?

            agent_config = "-javaagent:#{agent_jar}=#{options.join(',')}"
            existing = project.test.options[:java_args] || []
            project.test.options[:java_args] = (existing.is_a?(Array) ? existing : [existing]) + [agent_config]
          end
        end
      end
      namespace 'jacoco' do
        desc 'Generate JaCoCo reports.'
        task 'report' do

          execution_files = []
          class_paths = []
          source_paths = []
          Buildr.projects.select { |p| p.jacoco.enabled? }.each do |project|
            execution_files << project.jacoco.destfile if File.exist?(project.jacoco.destfile)
            target = project.compile.target.to_s
            class_paths << target.to_s if File.exist?(target)
            project.compile.sources.flatten.map(&:to_s).each do |src|
              source_paths << src.to_s if File.exist?(src)
            end
          end

          project = Buildr.projects[0].root_project

          options = {}
          options[:xml_output_file] = project._(:reports, :jacoco, 'jacoco.xml')
          options[:csv_output_file] = project._(:reports, :jacoco, 'jacoco.csv')
          options[:html_output_directory] = project._(:reports, :jacoco, 'docs')

          unless execution_files.empty?
            FileUtils.mkdir_p File.dirname(options[:xml_output_file])
            FileUtils.mkdir_p File.dirname(options[:csv_output_file])
            FileUtils.mkdir_p options[:html_output_directory]
            Buildr::JaCoCo.jacoco_report(execution_files, class_paths, source_paths, options)
          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::JaCoCo::ProjectExtension
end
