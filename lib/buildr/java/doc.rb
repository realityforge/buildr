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
  module Doc #:nodoc:

    module JavadocDefaults
      include Extension

      # Default javadoc -windowtitle to project's comment or name
      after_define(:javadoc => :doc) do |project|
        if project.doc.engine? Javadoc
          options = project.doc.options
          options[:windowtitle] = (project.comment || project.name) unless options[:windowtitle]
          project.doc.sourcepath = project.compile.sources.dup if project.doc.sourcepath.empty?
        end
      end
    end

    # A convenient task for creating Javadocs from the project's compile task. Minimizes all
    # the hard work to calling #from and #using.
    #
    # For example:
    #   doc.from(projects('myapp:foo', 'myapp:bar')).using(:windowtitle=>'My App')
    # Or, short and sweet:
    #   desc 'My App'
    #   define 'myapp' do
    #     . . .
    #     doc projects('myapp:foo', 'myapp:bar')
    #   end
    class Javadoc < Base

      specify :language => :java, :source_ext => 'java'

      def generate(sources, target, options = {})
        options = options.dup
        options[trace?(:javadoc) ? :verbose : :quiet] = true
        options[:output] = target

        Java::Commands.javadoc(*sources.flatten.uniq, options)
      end
    end
  end

  class Project #:nodoc:
    include JavadocDefaults
  end
end

Buildr::Doc.engines << Buildr::Doc::Javadoc
