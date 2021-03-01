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
  module Packaging #:nodoc:

    # Adds packaging for Java projects: JAR, WAR, AAR, EAR, Javadoc.
    module Java

      class Manifest

        STANDARD_HEADER = { 'Manifest-Version'=>'1.0', 'Created-By'=>'Buildr' }
        LINE_SEPARATOR = /\r\n|\n|\r[^\n]/ #:nodoc:
        SECTION_SEPARATOR = /(#{LINE_SEPARATOR}){2}/ #:nodoc:

        class << self

          # :call-seq:
          #   parse(str) => manifest
          #
          # Parse a string in MANIFEST.MF format and return a new Manifest.
          def parse(str)
            sections = str.split(SECTION_SEPARATOR).reject { |s| s.strip.empty? }
            new sections.map { |section|
              lines = section.split(LINE_SEPARATOR).inject([]) { |merged, line|
                if line[/^ /] == ' '
                  merged.last << line[1..-1]
                else
                  merged << line
                end
                merged
              }
              lines.map { |line| line.scan(/(.*?):\s*(.*)/).first }.
                inject({}) { |map, (key, value)| map.merge(key=>value) }
            }
          end

          # :call-seq:
          #   from_zip(file) => manifest
          #
          # Parse the MANIFEST.MF entry of a ZIP (or JAR) file and return a new Manifest.
          def from_zip(file)
            Zip::File.open(file.to_s) do |zip|
              return Manifest.parse zip.read('META-INF/MANIFEST.MF') if zip.find_entry('META-INF/MANIFEST.MF')
            end
            Manifest.new
          end

          # :call-seq:
          #   update_manifest(file) { |manifest| ... }
          #
          # Updates the MANIFEST.MF entry of a ZIP (or JAR) file.  Reads the MANIFEST.MF,
          # yields to the block with the Manifest object, and writes the modified object
          # back to the file.
          def update_manifest(file)
            manifest = from_zip(file)
            result = yield manifest
            Zip::File.open(file.to_s) do |zip|
              zip.get_output_stream('META-INF/MANIFEST.MF') do |out|
                out.write manifest.to_s
                out.write "\n"
              end
            end
            result
          end

        end

        # Returns a new Manifest object based on the argument:
        # * nil         -- Empty Manifest.
        # * Hash        -- Manifest with main section using the hash name/value pairs.
        # * Array       -- Manifest with one section from each entry (must be hashes).
        # * String      -- Parse (see Manifest#parse).
        # * Proc/Method -- New Manifest from result of calling proc/method.
        def initialize(arg = nil)
          case arg
          when nil, Hash then @sections = [arg || {}]
          when Array then @sections = arg
          when String then @sections = Manifest.parse(arg).sections
          when Proc, Method then @sections = Manifest.new(arg.call).sections
          else
            fail 'Invalid manifest, expecting Hash, Array, file name/task or proc/method.'
          end
          # Add Manifest-Version and Created-By, if not specified.
          STANDARD_HEADER.each do |name, value|
            sections.first[name] ||= value
          end
        end

        # The sections of this manifest.
        attr_reader :sections

        # The main (first) section of this manifest.
        def main
          sections.first
        end

        include Enumerable

        # Iterate over each section and yield to block.
        def each(&block)
          @sections.each(&block)
        end

        # Convert to MANIFEST.MF format.
        def to_s
          @sections.map { |section|
            keys = section.keys
            keys.unshift('Name') if keys.delete('Name')
            lines = keys.map { |key| manifest_wrap_at_72("#{key}: #{section[key]}") }
            lines + ['']
          }.flatten.join("\n")
        end

      private

        def manifest_wrap_at_72(line)
          return [line] if line.size < 72
          [ line[0..70] ] + manifest_wrap_at_72(' ' + line[71..-1])
        end

      end


      # Adds support for MANIFEST.MF and other META-INF files.
      module WithManifest #:nodoc:

        class << self
          def included(base)
            base.class_eval do
              alias :initialize_without_manifest :initialize
              alias :initialize :initialize_with_manifest
            end
          end

        end

        # Specifies how to create the manifest file.
        attr_accessor :manifest

        # Specifies files to include in the META-INF directory.
        attr_accessor :meta_inf

        def initialize_with_manifest(*args) #:nodoc:
          initialize_without_manifest *args
          @manifest = false
          @meta_inf = []
          @dependencies = FileList[]

          prepare do
            @prerequisites << manifest if String === manifest || Rake::Task === manifest
            [meta_inf].flatten.map { |file| file.to_s }.uniq.each { |file| path('META-INF').include file }
          end

          enhance do
            if manifest
              # Tempfiles gets deleted on garbage collection, so we're going to hold on to it
              # through instance variable not closure variable.
              @manifest_tmp = Tempfile.new('MANIFEST.MF')
              File.chmod 0644, @manifest_tmp.path
              self.manifest = File.read(manifest.to_s) if String === manifest || Rake::Task === manifest
              self.manifest = Manifest.new(manifest) unless Manifest === manifest
              #@manifest_tmp.write Manifest::STANDARD_HEADER
              @manifest_tmp.write manifest.to_s
              @manifest_tmp.write "\n"
              @manifest_tmp.close
              path('META-INF').include @manifest_tmp.path, :as=>'MANIFEST.MF'
            end
          end
        end

      end

      class ::Buildr::ZipTask
        include WithManifest
      end


      # Extends the ZipTask to create a JAR file.
      #
      # This task supports two additional attributes: manifest and meta-inf.
      #
      # The manifest attribute specifies how to create the MANIFEST.MF file.
      # * A hash of manifest properties (name/value pairs).
      # * An array of hashes, one for each section of the manifest.
      # * A string providing the name of an existing manifest file.
      # * A file task can be used the same way.
      # * Proc or method called to return the contents of the manifest file.
      # * False to not generate a manifest file.
      #
      # The meta-inf attribute lists one or more files that should be copied into
      # the META-INF directory.
      #
      # For example:
      #   package(:jar).with(:manifest=>'src/MANIFEST.MF')
      #   package(:jar).meta_inf << file('README')
      class JarTask < ZipTask

        def initialize(*args) #:nodoc:
          super
          enhance do
            pom.invoke rescue nil if respond_to?(:pom) && pom && pom != self && classifier.nil?
          end
        end

        # :call-seq:
        #   with(options) => self
        #
        # Additional
        # Pass options to the task. Returns self. ZipTask itself does not support any options,
        # but other tasks (e.g. JarTask, WarTask) do.
        #
        # For example:
        #   package(:jar).with(:manifest=>'MANIFEST_MF')
        def with(*args)
          super args.pop if Hash === args.last
          fail 'package.with() should not contain nil values' if args.include? nil
          include :from=>args if args.size > 0
          self
        end
      end


      # Extends the JarTask to create a WAR file.
      #
      # Supports all the same options as JarTask, in additon to these two options:
      # * :libs -- An array of files, tasks, artifact specifications, etc that will be added
      #   to the WEB-INF/lib directory.
      # * :classes -- A directory containing class files for inclusion in the WEB-INF/classes
      #   directory.
      #
      # For example:
      #   package(:war).with(:libs=>'log4j:log4j:jar:1.1')
      class WarTask < JarTask

        # Directories with class files to include under WEB-INF/classes.
        attr_accessor :classes

        # Artifacts to include under WEB-INF/libs.
        attr_accessor :libs

        def initialize(*args) #:nodoc:
          super
          @classes = []
          @libs = []
          enhance do |war|
            @libs.each {|lib| lib.invoke if lib.respond_to?(:invoke) }
            @classes.to_a.flatten.each { |classes| include classes, :as => 'WEB-INF/classes' }
            path('WEB-INF/lib').include Buildr.artifacts(@libs) unless @libs.nil? || @libs.empty?
          end
        end

        def libs=(value) #:nodoc:
          @libs = Buildr.artifacts(value)
        end

        def classes=(value) #:nodoc:
          @classes = [value].flatten.map { |dir| file(dir.to_s) }
        end
      end

      include Extension

      before_define(:package => :build) do |project|
        if project.parent && project.parent.manifest
          project.manifest = project.parent.manifest.dup
        else
          project.manifest = {
            'Build-By'=>ENV['USER'], 'Build-Jdk'=>ENV_JAVA['java.version'],
            'Implementation-Title'=>project.comment || project.name,
            'Implementation-Version'=>project.version }
        end
        if project.parent && project.parent.meta_inf
          project.meta_inf = project.parent.meta_inf.dup
        else
          project.meta_inf = [project.file('LICENSE')].select { |file| File.exist?(file.to_s) }
        end
      end


      # Manifest used for packaging. Inherited from parent project. The default value is a hash that includes
      # the Build-By, Build-Jdk, Implementation-Title and Implementation-Version values.
      # The later are taken from the project's comment (or name) and version number.
      attr_accessor :manifest

      # Files to always include in the package META-INF directory. The default value include
      # the LICENSE file if one exists in the project's base directory.
      attr_accessor :meta_inf

      # :call-seq:
      #   package_with_sources(options?)
      #
      # Call this when you want the project (and all its sub-projects) to create a source distribution.
      # You can use the source distribution in an IDE when debugging.
      #
      # A source distribution is a jar package with the classifier 'sources', which includes all the
      # sources used by the compile task.
      #
      # Packages use the project's manifest and meta_inf properties, which you can override by passing
      # different values (e.g. false to exclude the manifest) in the options.
      #
      # To create source distributions only for specific projects, use the :only and :except options,
      # for example:
      #   package_with_sources :only=>['foo:bar', 'foo:baz']
      #
      # (Same as calling package :sources on each project/sub-project that has source directories.)
      def package_with_sources(options = nil)
        options ||= {}
        enhance do
          selected = options[:only] ? projects(options[:only]) :
            options[:except] ? ([self] + projects - projects(options[:except])) :
            [self] + projects
          selected.reject { |project| project.compile.sources.empty? && project.resources.target.nil? }.
            each { |project| project.package(:sources) }
        end
      end

      # :call-seq:
      #   package_with_javadoc(options?)
      #
      # Call this when you want the project (and all its sub-projects) to create a JavaDoc distribution.
      # You can use the JavaDoc distribution in an IDE when coding against the API.
      #
      # A JavaDoc distribution is a ZIP package with the classifier 'javadoc', which includes all the
      # sources used by the compile task.
      #
      # Packages use the project's manifest and meta_inf properties, which you can override by passing
      # different values (e.g. false to exclude the manifest) in the options.
      #
      # To create JavaDoc distributions only for specific projects, use the :only and :except options,
      # for example:
      #   package_with_javadoc :only=>['foo:bar', 'foo:baz']
      #
      # (Same as calling package :javadoc on each project/sub-project that has source directories.)
      def package_with_javadoc(options = nil)
        options ||= {}
        enhance do
          selected = options[:only] ? projects(options[:only]) :
            options[:except] ? ([self] + projects - projects(options[:except])) :
            [self] + projects
          selected.reject { |project| project.compile.sources.empty? }.
            each { |project| project.package(:javadoc) }
        end
      end

      def package_as_jar(file_name) #:nodoc:
        Java::JarTask.define_task(file_name).tap do |jar|
          jar.with :manifest=>manifest, :meta_inf=>meta_inf
          jar.with [compile.target, resources.target].compact
        end
      end

      def package_as_war(file_name) #:nodoc:
        Java::WarTask.define_task(file_name).tap do |war|
          war.with :manifest=>manifest, :meta_inf=>meta_inf
          # Add libraries in WEB-INF lib, and classes in WEB-INF classes
          war.with :classes=>[compile.target, resources.target].compact
          war.with :libs=>compile.dependencies
          webapp = path_to(:source, :main, :webapp)
          war.with webapp if File.exist?(webapp)
          war.enhance([assets])
          war.include assets.to_s, :as => '.' unless assets.paths.empty?
        end
      end

      def package_as_javadoc_spec(spec) #:nodoc:
        spec.merge(:type=>:jar, :classifier=>'javadoc')
      end

      def package_as_javadoc(file_name) #:nodoc:
        ZipTask.define_task(file_name).tap do |zip|
          zip.include :from=>doc.target
        end
      end
    end
  end
end

class Buildr::Project #:nodoc:
  include Buildr::Packaging::Java
end
