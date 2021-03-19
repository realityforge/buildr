#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Buildr
  # Provides the shade method.
  module Shade

    class << self

      # The specs for requirements
      def dependencies
        %w(
          net.sourceforge.pmd:pmd-core:jar:6.11.0
          net.sourceforge.pmd:pmd-java:jar:6.11.0
          net.sourceforge.pmd:pmd-java8:jar:6.11.0
          jaxen:jaxen:jar:1.1.6
          commons-io:commons-io:jar:2.6
          com.beust:jcommander:jar:1.72
          org.ow2.asm:asm:jar:7.1
          com.google.code.gson:gson:jar:2.8.5
          net.java.dev.javacc:javacc:jar:5.0
          net.sourceforge.saxon:saxon:jar:9.1.0.8
          org.apache.commons:commons-lang3:jar:3.8.1
          org.antlr:antlr4-runtime:jar:4.7
        )
      end

      def shade(input_jar, output_jar, relocations = {})

        shaded_jar = (input_jar.to_s + '-shaded')
        a = Buildr.artifact('org.realityforge.shade:shade-cli:jar:1.0.0')
        a.invoke

        args = []
        args << Java::Commands.path_to_bin('java')
        args << '-jar'
        args << a.to_s
        args << '--input'
        args << input_jar.to_s
        args << '--output'
        args << shaded_jar.to_s
        relocations.each_pair do |k, v|
          args << "-r#{k}#{v}"
        end

        sh args.join(' ')
        FileUtils.mv shaded_jar, output_jar.to_s
      end
    end
  end
end
