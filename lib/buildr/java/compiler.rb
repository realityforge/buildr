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
  module Compiler #:nodoc:

    # Javac compiler:
    #   compile.using(:javac)
    # Used by default if .java files are found in the src/main/java directory (or src/test/java)
    # and sets the target directory to target/classes (or target/test/classes).
    #
    # Accepts the following options:
    # * :warnings    -- Issue warnings when compiling.  True when running in verbose mode.
    # * :debug       -- Generates bytecode with debugging information.  Set from the debug
    # environment variable/global option.
    # * :deprecation -- If true, shows deprecation messages.  False by default.
    # * :source      -- Source code compatibility.
    # * :target      -- Bytecode compatibility.
    # * :lint        -- Lint option is one of true, false (default), name (e.g. 'cast') or array.
    # * :other       -- Array of options passed to the compiler
    # (e.g. ['-implicit:none', '-encoding', 'iso-8859-1'])
    class Javac < Base

      OPTIONS = [:warnings, :debug, :deprecation, :source, :target, :lint, :other]

      specify :language => :java, :target => 'classes', :target_ext => 'class', :packaging => :jar

      def initialize(project, options) #:nodoc:
        super
        options[:debug] = Buildr.options.debug if options[:debug].nil?
        options[:warnings] ||= false
        options[:deprecation] ||= false
        options[:lint] ||= false
      end

      def compile(sources, target, dependencies) #:nodoc:
        check_options options, OPTIONS
        Java::Commands.javac(files_from_sources(sources),
                             :classpath => dependencies,
                             :sourcepath => sources.select { |source| File.directory?(source) },
                             :output => target,
                             :javac_args => self.javac_args)
      end

      # Filter out source files that are known to not produce any corresponding .class output file. If we leave
      # this type of file in the generated compile map the compiler will always be run due to missing output files.
      def compile_map(sources, target)
        map = super
        map.reject! { |key,_| File.basename(key) == 'package-info.java' } || map
      end

    private

      def javac_args #:nodoc:
        args = []
        args << '-nowarn' unless options[:warnings]
        args << '-verbose' if trace?(:javac)
        args << '-g' if options[:debug]
        args << '-deprecation' if options[:deprecation]
        args << '-source' << options[:source].to_s if options[:source]
        args << '-target' << options[:target].to_s if options[:target]
        case options[:lint]
          when Array  then args << "-Xlint:#{options[:lint].join(',')}"
          when String then args << "-Xlint:#{options[:lint]}"
          when true   then args << '-Xlint'
        end
        args + Array(options[:other])
      end
    end
  end
end

Buildr::Compiler << Buildr::Compiler::Javac
