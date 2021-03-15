# This file is licensed to you under the Apache License, Version 2.0 (the
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
  module ProcessorPath
    module ProjectExtension
      include Extension

      before_define do |project|
        if project.iml?
          project.iml.instance_variable_set('@main_generated_source_directories', [])
          project.iml.instance_variable_set('@test_generated_source_directories', [])
          project.iml.instance_variable_set('@processorpath', {})
        end
      end

      after_define do |project|
        if project.compile.processor?
          project.file(project._(:target, :generated, 'processors/main/java'))
          project.compile.enhance do
            mkdir_p project._(:target, :generated, 'processors/main/java')
          end
          project.compile.options[:other] = [] unless project.compile.options[:other]
          project.compile.options[:other] += ['-s', project._(:target, :generated, 'processors/main/java')]
          project.iml.main_generated_source_directories << project._(:target, :generated, 'processors/main/java') if project.iml?

          project.clean do
            rm_rf project._(:target, :generated, 'processors/main/java')
          end
        end
        if project.test.compile.processor?
          project.file(project._(:target, :generated, 'processors/test/java'))
          project.test.compile.enhance do
            mkdir_p project._(:target, :generated, 'processors/test/java')
          end
          project.test.compile.options[:other] = [] unless project.test.compile.options[:other]
          project.test.compile.options[:other] += ['-s', project._(:target, :generated, 'processors/test/java')]
          project.iml.test_generated_source_directories << project._(:target, :generated, 'processors/test/java') if project.iml?

          project.clean do
            rm_rf project._(:target, :generated, 'processors/test/java')
          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::ProcessorPath::ProjectExtension
end
