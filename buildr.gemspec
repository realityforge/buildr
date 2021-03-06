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

unless defined?(Buildr::VERSION)
  require File.join(File.dirname(__FILE__), 'lib', 'buildr', 'version.rb')
  $LOADED_FEATURES << 'buildr/version.rb'
end

Gem::Specification.new do |spec|
  spec.name           = 'realityforge-buildr'
  spec.version        = Buildr::VERSION.dup
  spec.platform       = Gem::Platform::RUBY
  spec.author         = 'Apache Buildr'
  spec.email          = 'users@buildr.apache.org'
  spec.homepage       = 'http://buildr.apache.org/'
  spec.summary        = 'Build like you code'
  spec.licenses        = %w(Apache-2.0)
  spec.description    = <<-TEXT
Apache Buildr is a build system for Java-based applications.  We wanted
something that's simple and intuitive to use, so we only need to tell it what
to do, and it takes care of the rest.  But also something we can easily extend
for those one-off tasks, with a language that's a joy to use.
  TEXT

  spec.files          = Dir['{addon,bin,lib,rakelib,spec}/**/*', '*.{gemspec}'] +
                        %w(LICENSE NOTICE README.md Rakefile)
  spec.require_paths  = 'lib', 'addon'
  spec.bindir         = 'bin'
  spec.executable     = 'buildr'

  spec.extra_rdoc_files = 'README.md', 'LICENSE', 'NOTICE'
  spec.rdoc_options     = '--title', 'Buildr', '--main', 'README.md',
                          '--webcvs', 'https://github.com/realityforge/buildr'
  spec.post_install_message = 'To get started run buildr --help'

  # Tested against these dependencies.
  spec.add_dependency 'rake',                 '0.9.2.2'
  spec.add_dependency 'builder',              '3.2.4'
  spec.add_dependency 'rubyzip',              '2.3.0'
  spec.add_dependency 'json_pure',            '2.5.1'
  spec.add_dependency 'xml-simple',           '1.1.8'
  spec.add_dependency 'bundler'

  spec.add_development_dependency 'rspec-expectations',   '2.14.3'
  spec.add_development_dependency 'rspec-mocks',          '2.14.3'
  spec.add_development_dependency 'rspec-core',           '2.14.5'
  spec.add_development_dependency 'rspec',                '2.14.1'
  spec.add_development_dependency 'rspec-retry',          '0.2.1'
end
