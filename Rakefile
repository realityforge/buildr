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

require 'psych'
require 'rubygems/package_task'
require 'rspec/core/rake_task'

# We need JAVA_HOME for most things (setup, spec, etc).
unless ENV['JAVA_HOME']
  if RUBY_PLATFORM[/darwin/]
    ENV['JAVA_HOME'] = '/System/Library/Frameworks/JavaVM.framework/Home'
  else
    fail "Please set JAVA_HOME first (set JAVA_HOME=... or env JAVA_HOME=... rake ...)"
  end
end

desc 'Clean up all temporary directories used for running tests, creating documentation, packaging, etc.'
task :clobber do
  rm_f 'failed'
  rm_rf '_reports'
  rm_rf '_target'
end

Gem::PackageTask.new(Gem::Specification.load('buildr.gemspec'))

directory '_reports'

desc 'Run all specs'
RSpec::Core::RakeTask.new :spec => ['_reports'] do |task|
  task.rspec_path = 'bundle exec rspec'
  task.rspec_opts = %w{--format html --out _reports/specs.html --backtrace}
end

desc 'Run all specs with CI reporter'
task 'ci' => %w(clobber spec)
