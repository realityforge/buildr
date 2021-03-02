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

if RbConfig::CONFIG['host_os'] =~ /darwin/i
  # On OS X we attempt to guess where JAVA_HOME is, if not set
  ENV['JAVA_HOME'] ||= '/System/Library/Frameworks/JavaVM.framework/Home'
end

# Base module for all things Java.
module Java

  # JDK commands: java, javac, javadoc, etc.
  module Commands

    class << self

      # :call-seq:
      #   java(class, *args, options?)
      #
      # Runs Java with the specified arguments.
      #
      # Each argument should be provided as separate array value, e.g.
      #
      #  java("-jar", "yuicompressor-2.4.2.jar", "--type","css",
      #       "src/main/webapp/styles/styles-all.css",
      #       "-o", "src/main/webapp/styles/styles-all-min.css")
      #
      # The last argument may be a Hash with additional options:
      # * :dir -- The working directory from which to execute task..
      # * :classpath -- One or more file names, tasks or artifact specifications.
      #   These are all expanded into artifacts, and all tasks are invoked.
      # * :java_args -- Any additional arguments to pass (e.g. -hotspot, -xms)
      # * :properties -- Hash of system properties (e.g. 'path'=>base_dir).
      # * :name -- Shows this name, otherwise shows the first argument (the class name).
      # * :verbose -- If true, prints the command and all its argument.
      # * :pathing_jar -- If true, forces the use of a "pathing" jar, false disables. Nil
      #                   will default to using a "pathing" jar under windows with long classpaths.
      #                   See http://stackoverflow.com/questions/201816/how-to-set-a-long-java-classpath-in-msdos-windows
      def java(*args, &block)
        options = Hash === args.last ? args.pop : {}
        options[:verbose] ||= trace?(:java)
        rake_check_options options, :classpath, :java_args, :properties, :name, :verbose, :dir, :pathing_jar

        name = options[:name]
        if name.nil?
          name = "java #{args.first}"
        end

        cmd_args = []
        if options[:dir]
          cmd_args << "cd '#{options[:dir]}' && "
        end
        cmd_args << path_to_bin('java')
        cp = classpath_from(options)

        unless cp.empty?
          if options[:pathing_jar] == true
            paths = cp.map do |c|
              File.directory?(c) && !c.end_with?('/') ? "#{c}/" : c.to_s
            end
            manifest = Buildr::Packaging::Java::Manifest.new([{'Class-Path' => paths.map{|p| URI.encode(p)}.join(" ")}])
            tjar = Tempfile.new(%w[javacmd .jar])
            Zip::OutputStream.open(tjar.path) do |zos|
              zos.put_next_entry('META-INF/MANIFEST.MF')
              zos.write manifest.to_s
              zos.write "\n"
            end
            tjar.close

            cmd_args << '-classpath' << tjar.path
          else
            cmd_args << '-classpath' << cp.join(File::PATH_SEPARATOR)
          end
        end
        options[:properties].each { |k, v| cmd_args << "-D#{k}=#{v}" } if options[:properties]
        cmd_args += (options[:java_args] || (ENV['JAVA_OPTS'] || ENV['JAVA_OPTIONS']).to_s.split).flatten
        cmd_args += args.flatten.compact

        tmp = nil
        begin
          unless Buildr.application.options.dryrun
            info "Running #{name}" if name && options[:verbose]
            block = lambda { |ok, res| fail "Failed to execute #{name}, see errors above" unless ok } unless block
            sh(*cmd_args) do |ok, ps|
              block.call ok, ps
            end
          end
        ensure
          unless tmp.nil?
            tmp.close
            tmp.unlink
          end
        end
      end

      # :call-seq:
      #   javac(*files, options)
      #
      # Runs Javac with the specified arguments.
      #
      # The last argument may be a Hash with additional options:
      # * :output -- Target directory for all compiled class files.
      # * :classpath -- One or more file names, tasks or artifact specifications.
      #   These are all expanded into artifacts, and all tasks are invoked.
      # * :sourcepath -- Additional source paths to use.
      # * :javac_args -- Any additional arguments to pass (e.g. -extdirs, -encoding)
      # * :name -- Shows this name, otherwise shows the working directory.
      def javac(*args, &block)
        options = Hash === args.last ? args.pop : {}
        rake_check_options options, :classpath, :sourcepath, :output, :javac_args, :name

        files = args.flatten.each { |f| f.invoke if f.respond_to?(:invoke) }.map(&:to_s).
          collect { |arg| File.directory?(arg) ? FileList["#{File.expand_path(arg)}/**/*.java"] : File.expand_path(arg) }.flatten
        name = options[:name] || Dir.pwd

        cmd_args = []
        cmd_args << path_to_bin('javac')
        cp = classpath_from(options)
        cmd_args << '-classpath' << cp.join(File::PATH_SEPARATOR) unless cp.empty?
        cmd_args << '-sourcepath' << [options[:sourcepath]].flatten.join(File::PATH_SEPARATOR) if options[:sourcepath]
        cmd_args << '-d' << File.expand_path(options[:output].to_s) if options[:output]
        cmd_args += options[:javac_args].flatten if options[:javac_args]
        Tempfile.open('javac') do |tmp|
          tmp.write files.join(' ')
          cmd_args << "@#{tmp.path}"
        end
        unless Buildr.application.options.dryrun
          mkdir_p options[:output] if options[:output]
          info "Compiling #{files.size} source files in #{name}"
          block = lambda { |ok, res| fail 'Failed to compile, see errors above' unless ok } unless block
          sh(*cmd_args) do |ok, ps|
            block.call ok, ps
          end
        end
      end

      # :call-seq:
      #   javadoc(*files, options, &block)
      #
      # Runs Javadocs with the specified files and options.
      #
      # This method accepts the following special options:
      # * :output -- The output directory
      # * :classpath -- Array of classpath dependencies.
      # * :sourcepath -- Array of sourcepaths (paths or tasks).
      # * :name -- Shows this name, otherwise shows the working directory.
      #
      # All other options are passed to Javadoc as following:
      # * true -- As is, for example, :author=>true becomes -author
      # * false -- Prefixed, for example, :index=>false becomes -noindex
      # * string -- Option with value, for example, :windowtitle=>'My project' becomes -windowtitle "My project"
      # * array -- Option with set of values separated by spaces.
      def javadoc(*args, &block)
        options = Hash === args.last ? args.pop : {}
        fail 'No output defined for javadoc' if options[:output].nil?
        options[:output] = File.expand_path(options[:output].to_s)
        cmd_args = []
        cmd_args << path_to_bin('javadoc')
        cmd_args << '-d' << options[:output]
        cmd_args << (trace?(:javadoc) ? '-verbose' : '-quiet')

        options.reject { |key, value| [:output, :name, :sourcepath, :classpath].include?(key) }.
          each { |key, value| value.invoke if value.respond_to?(:invoke) }.
          each do |key, value|
            case value
            when true, nil
              cmd_args << "-#{key}"
            when false
              cmd_args << "-no#{key}"
            when Hash
              value.each { |k,v| cmd_args << "-#{key}" << k.to_s << v.to_s }
            else
              cmd_args += Array(value).map { |item| ["-#{key}", item.to_s] }.flatten
            end
          end
        [:sourcepath, :classpath].each do |option|
          options[option].to_a.flatten.tap do |paths|
            cmd_args << "-#{option}" << paths.flatten.map(&:to_s).join(File::PATH_SEPARATOR) unless paths.empty?
          end
        end
        files = args.each {|arg| arg.invoke if arg.respond_to?(:invoke)}.collect {|arg| arg.is_a?(Project) ? arg.compile.sources.collect{|dir| Dir["#{File.expand_path(dir.to_s)}/**/*.java"]} : File.expand_path(arg.to_s) }
        cmd_args += files.flatten.uniq.map(&:to_s)
        name = options[:name] || Dir.pwd
        unless Buildr.application.options.dryrun
          info "Generating Javadoc for #{name}"
          trace(cmd_args.join(' '))
          block = lambda { |ok, res| fail 'Failed to generate Javadocs, see errors above' unless ok } unless block
          sh(*cmd_args) do |ok, ps|
            block.call ok, ps
          end
        end
      end

    protected

      # :call-seq:
      #   path_to_bin(cmd?) => path
      #
      # Returns the path to the specified Java command (with no argument to java itself).
      def path_to_bin(name = nil)
        home = ENV['JAVA_HOME'] or fail 'Are we forgetting something? JAVA_HOME not set.'
        bin = File.expand_path(File.join(home, 'bin'))
        fail 'JAVA_HOME environment variable does not point to a valid JRE/JDK installation.' unless File.exist? bin
        File.expand_path(File.join(bin, name.to_s))
      end

      # :call-seq:
      #    classpath_from(options) => files
      #
      # Extracts the classpath from the options, expands it by calling artifacts, invokes
      # each of the artifacts and returns an array of paths.
      def classpath_from(options)
        Buildr.artifacts(options[:classpath] || []).map(&:to_s).
          map { |t| task(t).invoke; File.expand_path(t) }
      end
    end
  end
end
