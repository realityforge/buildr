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

require 'rubygems/package_task'

Gem::PackageTask.new(spec)

desc 'Compile Java libraries used by Buildr'
task 'compile' do
  puts 'Compiling Java libraries ...'
  args = RbConfig::CONFIG['ruby_install_name'], File.expand_path('_buildr'), '--buildfile', 'buildr.buildfile', 'compile'
  args << '--trace' if Rake.application.options.trace
  sh *args
end
file Gem::PackageTask.new(spec).package_dir => 'compile'
file Gem::PackageTask.new(spec).package_dir_path => 'compile'

# We also need the other packages (JRuby if building on Ruby, and vice versa)
# Must call new with block, even if block does nothing, otherwise bad things happen.
@specs.values.each do |s|
  Gem::PackageTask.new(s) { |task| }
end

task('clobber') { rm_rf 'target' }
