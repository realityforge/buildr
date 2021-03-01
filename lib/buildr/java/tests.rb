
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
        unless @dependencies
          super
          # Add buildr utility classes (e.g. JavaTestFilter)
          @dependencies |= [ File.join(File.dirname(__FILE__)) ]
        end
        @dependencies
      end
    end

  private

    # Add buildr utilities (JavaTestFilter) to classpath
    Java.classpath << lambda { dependencies }

    # :call-seq:
    #     filter_classes(dependencies, criteria)
    #
    # Return a list of classnames that match the given criteria.
    # The criteria parameter is a hash that must contain at least one of:
    #
    # * :class_names -- List of patterns to match against class name
    # * :interfaces -- List of java interfaces or java classes
    # * :class_annotations -- List of annotations on class level
    # * :method_annotations -- List of annotations on method level
    # * :fields -- List of java field names
    #
    def filter_classes(dependencies, criteria = {})
      return [] unless task.compile.target
      target = task.compile.target.to_s
      candidates = Dir["#{target}/**/*.class"].
        map { |file| Util.relative_path(file, target).ext('').gsub(File::SEPARATOR, '.') }.
        reject { |name| name =~ /\$./ }
      result = []
      if criteria[:class_names]
        result.concat candidates.select { |name| criteria[:class_names].flatten.any? { |pat| pat === name } }
      end
      begin
        Java.load
        filter = Java.org.apache.buildr.JavaTestFilter.new(dependencies.to_java(Java.java.lang.String))
        if criteria[:interfaces]
          filter.add_interfaces(criteria[:interfaces].to_java(Java.java.lang.String))
        end
        if criteria[:class_annotations]
          filter.add_class_annotations(criteria[:class_annotations].to_java(Java.java.lang.String))
        end
        if criteria[:method_annotations]
          filter.add_method_annotations(criteria[:method_annotations].to_java(Java.java.lang.String))
        end
        if criteria[:fields]
          filter.add_fields(criteria[:fields].to_java(Java.java.lang.String))
        end
        result.concat filter.filter(candidates.to_java(Java.java.lang.String)).map(&:to_s)
      rescue =>ex
        info "#{ex.class}: #{ex.message}"
        raise
      end
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

    VERSION = '6.11'

    class << self
      def version
        Buildr.settings.build['testng'] || VERSION
      end

      def dependencies
        %W(org.testng:testng:jar:#{version} com.beust:jcommander:jar:1.27)
      end
    end

    def tests(dependencies) #:nodoc:
      filter_classes(dependencies,
                     :class_annotations => %w{org.testng.annotations.Test},
                     :method_annotations => %w{org.testng.annotations.Test})
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
      failed_tests = File.join(task.report_to.to_s, 'testng-failed.xml')
      if File.exist?(failed_tests)
        report = File.read(failed_tests)
        failed = report.scan(/<class name="(.*?)">/im).flatten
        # return the list of passed tests
        return tests - failed
      else
        return tests
      end
    end
  end
end # Buildr

Buildr::TestFramework << Buildr::TestNG
