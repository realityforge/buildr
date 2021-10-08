
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

module Buildr #:nodoc:

  class TestFramework::Java < TestFramework::Base

    class << self

      def applies_to?(project) #:nodoc:
        project.test.compile.language == :java
      end

      def dependencies
        super
      end
    end

  private

    def derive_test_candidates
      return [] unless task.compile.target
      target = task.compile.target.to_s
      Dir["#{target}/**/*.class"].
        map { |file| Util.relative_path(file, target).ext('').gsub(File::SEPARATOR, '.') }.
        reject { |name| name =~ /\$./ }
    end
  end

  # TestNG test framework.  To use in your project:
  #   test.using :testng
  #
  # Support the following options:
  # * :properties -- Hash of properties passed to the test suite.
  # * :java_args -- Arguments passed to the JVM.
  # * :args -- Arguments passed to the TestNG command line runner.
  class TestNG < TestFramework::Java

    class << self
      def dependencies
        %w(org.testng:testng:jar:7.4.0 com.beust:jcommander:jar:1.78 org.webjars:jquery:jar:3.5.1)
      end
    end

    def tests(dependencies) #:nodoc:
      candidates = derive_test_candidates

      # Ugly hack that probably works for all of our codebases
      test_include = /.*Test$/
      test_exclude = /(^|\.)Abstract[^.]*$/
      candidates.select{|c| c =~ test_include }.select{|c| !(c =~ test_exclude) }.dup
    end

    def run(tests, dependencies) #:nodoc:
      cmd_args = []
      cmd_args << '-suitename' << task.project.id
      cmd_args << '-log' << '2'
      cmd_args << '-d' << task.report_to.to_s
      exclude_args = options[:excludegroups] || []
      unless exclude_args.empty?
        cmd_args << '-excludegroups' << exclude_args.join(',')
      end
      groups_args = options[:groups] || []
      unless groups_args.empty?
        cmd_args << '-groups' << groups_args.join(',')
      end
      # run all tests in the same suite
      cmd_args << '-testclass' << tests.join(',')

      cmd_args += options[:args] if options[:args]

      cmd_options = { :properties=>options[:properties], :java_args=>options[:java_args],
        :classpath=>dependencies, :name => "TestNG in #{task.send(:project).name}" }

      tmp = nil
      begin
        tmp = Tempfile.open('testNG')
        tmp.write cmd_args.join("\n")
        tmp.close
        Java::Commands.java ['org.testng.TestNG', "@#{tmp.path}"], cmd_options
      ensure
        tmp.close unless tmp.nil?
      end
      # testng-failed.xml contains the list of failed tests *only*
      failed_tests = File.join(task.report_to.to_s, task.project.id.to_s, 'Command line test.xml')
      if File.exist?(failed_tests)
        report = File.read(failed_tests)
        failed = report.scan(/<testcase [^>]+ classname="([^"]+)">/im).flatten
        # return the list of passed tests
        tests - failed
      else
        tests
      end
    end
  end
end # Buildr

Buildr::TestFramework << Buildr::TestNG
