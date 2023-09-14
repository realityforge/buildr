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
          project.clean { rm_rf project._(:target, :generated, :processors) }
        end
      end

      after_define do |project|
        Buildr.artifacts((project.compile.options[:processor_path] || []) + (project.test.compile.options[:processor_path] || [])).flatten.map(&:to_s).map do |t|
          Rake::Task['rake:artifacts'].enhance([task(t)])
        end
        if !!project.compile.options[:processor] || (project.compile.options[:processor].nil? && !(project.compile.options[:processor_path] || []).empty?)
          path = project._(:target, :generated, 'processors/main/java')
          f = project.file(path) do |t|
            mkdir_p t.to_s
          end
          project.compile.enhance([f])
          project.compile.options[:other] = [] unless project.compile.options[:other]
          project.compile.options[:other] += ['-s', path]
          project.iml.main_generated_source_directories << path if project.iml?

          project.clean do
            rm_rf path
          end
        end
        if !!project.test.compile.options[:processor] || (project.test.compile.options[:processor].nil? && !(project.test.compile.options[:processor_path] || []).empty?)
          path = project._(:target, :generated, 'processors/test/java')
          f = project.file(path) do |t|
            mkdir_p t.to_s
          end
          project.test.compile.enhance([f])
          project.test.compile.options[:other] = [] unless project.test.compile.options[:other]
          project.test.compile.options[:other] += ['-s', path]
          project.iml.test_generated_source_directories << path if project.iml?

          project.clean do
            rm_rf path
          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::ProcessorPath::ProjectExtension
end
