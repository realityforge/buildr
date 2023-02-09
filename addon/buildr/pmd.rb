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
  # Provides the <code>pmd:xml</code> and <code>pmd:html</code> tasks.
  #
  # Require explicitly using <code>require 'buildr/pmd'</code>.
  module Pmd

    class << self

      # The specs for requirements
      def dependencies
        %w(
          net.sourceforge.pmd:pmd-core:jar:6.54.0
          net.sourceforge.pmd:pmd-java:jar:6.54.0
          jaxen:jaxen:jar:1.1.6
          com.beust:jcommander:jar:1.48
          org.ow2.asm:asm:jar:9.3
          com.google.code.gson:gson:jar:2.8.9
          net.java.dev.javacc:javacc:jar:5.0
          net.sourceforge.saxon:saxon:jar:9.1.0.8
          org.apache.commons:commons-lang3:jar:3.8.1
          org.antlr:antlr4-runtime:jar:4.7.2
        )
      end

      def pmd(rule_set_files, format, output_file_prefix, source_paths, options = {})
        dependencies = (options[:dependencies] || []) + self.dependencies
        cp = Buildr.artifacts(dependencies).each(&:invoke).map(&:to_s)
        (options[:rule_set_paths] || []).each {|p| cp << p}

        rule_sets = rule_set_files.dup

        Buildr.artifacts(options[:rule_set_artifacts] || []).each do |artifact|
          a = artifact.to_s
          dirname = File.dirname(a)
          rule_sets << a[dirname.length + 1, a.length]
          cp << File.dirname(a)
          artifact.invoke
        end

        puts 'PMD: Analyzing source code...'
        mkdir_p File.dirname(output_file_prefix)

        args = []
        args << '--no-cache'
        args << '--relativize-paths-with'
        args << '--rulesets' << rule_sets.join(',')
        args << '--format' << format
        args << '--report-file' << "#{output_file_prefix}.#{format}"
        #args << '--aux-classpath' << cp.join(':')

        files = []
        source_paths.each do |src|
          files += Dir["#{src}/**/*.java"] if File.directory?(src)
        end
        files = files.sort.uniq

        Tempfile.open('pmd') do |tmp|
          tmp.write files.join(',')
          args << '--file-list' << tmp.path.to_s
        end

        begin
          Java::Commands.java 'net.sourceforge.pmd.PMD', *(args + [{:classpath => cp, :properties => options[:properties], :java_args => options[:java_args]}])
        rescue Exception => e
          raise e if options[:fail_on_error]
        end
      end
    end

    class Config

      attr_writer :enabled

      def enabled?
        !!@enabled
      end

      attr_writer :rule_set_files

      def rule_set_files
        @rule_set_files ||= (self.rule_set_artifacts.empty? ? %w(rulesets/java/basic.xml rulesets/java/imports.xml rulesets/java/unusedcode.xml rulesets/java/finalizers.xml rulesets/java/braces.xml) : [])
      end

      # Support specification of rule sets that are distributed as part of a maven repository
      def rule_set_artifacts
        @rule_set_artifacts ||= []
      end

      attr_writer :rule_set_paths

      def rule_set_paths
        @rule_set_paths ||= []
      end

      attr_writer :report_dir

      def report_dir
        @report_dir || project._(:reports, :pmd)
      end

      attr_writer :output_file_prefix

      def output_file_prefix
        @output_file_prefix || "#{self.report_dir}/pmd"
      end

      def source_paths
        @source_paths ||= [self.project.compile.sources, self.project.test.compile.sources].flatten.compact
      end

      # An array of paths that should be excluded no matter how they are added to pmd
      def exclude_paths
        @exclude_paths ||= []
      end

      # An array of additional projects to scan for main and test sources
      attr_writer :additional_project_names

      def additional_project_names
        @additional_project_names ||= []
      end

      def flat_source_paths
        paths = source_paths.dup

        self.additional_project_names.each do |project_name|
          p = self.project.project(project_name)
          paths << [p.compile.sources, p.test.compile.sources].flatten.compact
        end

        paths.flatten.select{|p|!self.exclude_paths.include?(p)}.compact
      end

      protected

      def initialize(project)
        @project = project
      end

      attr_reader :project
    end

    module ProjectExtension
      include Extension

      def pmd
        @pmd ||= Buildr::Pmd::Config.new(project)
      end

      after_define do |project|
        if project.pmd.enabled?
          desc 'Generate pmd xml report.'
          project.task('pmd:xml') do
            Buildr::Pmd.pmd(project.pmd.rule_set_files, 'xml', project.pmd.output_file_prefix, project.pmd.flat_source_paths, :rule_set_paths => project.pmd.rule_set_paths, :rule_set_artifacts => project.pmd.rule_set_artifacts)
          end

          desc 'Generate pmd html report.'
          project.task('pmd:html') do
            Buildr::Pmd.pmd(project.pmd.rule_set_files, 'html', project.pmd.output_file_prefix, project.pmd.flat_source_paths, :rule_set_paths => project.pmd.rule_set_paths, :rule_set_artifacts => project.pmd.rule_set_artifacts)
          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::Pmd::ProjectExtension
end
