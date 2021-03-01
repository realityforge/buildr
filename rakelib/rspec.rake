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

require 'rspec/core/rake_task'
directory '_reports'

# RSpec doesn't support file exclusion, so hack our own.
class RSpec::Core::RakeTask
  attr_accessor :rspec_files
  private
  def files_to_run
    @rspec_files
  end
end

desc 'Run all specs'
RSpec::Core::RakeTask.new :spec => ['_reports', :compile] do |task|
  ENV['USE_FSC'] = 'no'
  files = FileList['spec/**/*_spec.rb']
  task.rspec_path = 'bundle exec rspec'
  task.rspec_files = files
  task.rspec_opts = %w{--order defined --format html --out _reports/specs.html --backtrace}
end
file('_reports/specs.html') { task(:spec).invoke }

desc 'Run all specs with CI reporter'
task 'ci' => %w(clobber spec)

task 'clobber' do
  rm_f 'failed'
  rm_rf '_reports'
  rm_rf 'tmp'
end
