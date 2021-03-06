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

  module Util
    extend self

    # Return the path to the first argument, starting from the path provided by the
    # second argument.
    #
    # For example:
    #   relative_path('foo/bar', 'foo')
    #   => 'bar'
    #   relative_path('foo/bar', 'baz')
    #   => '../foo/bar'
    #   relative_path('foo/bar')
    #   => 'foo/bar'
    #   relative_path('/foo/bar', 'baz')
    #   => '/foo/bar'
    def relative_path(to, from = '.')
      to = Pathname.new(to).cleanpath
      return to.to_s if from.nil?
      to_path = Pathname.new(File.expand_path(to.to_s, "/"))
      from_path = Pathname.new(File.expand_path(from.to_s, "/"))
      to_path.relative_path_from(from_path).to_s
    end

    # Generally speaking, it's not a good idea to operate on dot files (files starting with dot).
    # These are considered invisible files (.svn, .hg, .irbrc, etc).  Dir.glob/FileList ignore them
    # on purpose.  There are few cases where we do have to work with them (filter, zip), a better
    # solution is welcome, maybe being more explicit with include.  For now, this will do.
    def recursive_with_dot_files(*dirs)
      FileList[dirs.map { |dir| File.join(dir, '/**/{*,.*}') }].reject { |file| File.basename(file) =~ /^[.]{1,2}$/ }
    end

    # Most platforms requires tools.jar to be on the classpath, tools.jar contains the
    # Java compiler (OS X and AIX are two exceptions we know about, may be more).
    # Guess where tools.jar is from JAVA_HOME, which hopefully points to the JDK,
    # but maybe the JRE.  Return nil if not found.
    def tools_jar #:nodoc:
      @tools_jar ||= begin
                       home = ENV['JAVA_HOME'] or fail 'Are we forgetting something? JAVA_HOME not set.'
                       %w[lib/tools.jar ../lib/tools.jar].map { |path| File.expand_path(path, home) }.
                         find { |path| File.exist?(path) }
                     end
    end
  end # Util
end

class OpenObject < Hash

  def initialize(source=nil, &block)
    super &block
    update source if source
  end

  def method_missing(symbol, *args)
    if symbol.to_s =~ /=$/
      self[symbol.to_s[0..-2].to_sym] = args.first
    else
      self[symbol]
    end
  end
end
