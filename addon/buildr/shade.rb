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
