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
  require 'buildr/version'
end

require 'rake'
include Rake::DSL
Rake::TaskManager.record_task_metadata = true

require 'rbconfig'
require 'pathname'
autoload :Tempfile, 'tempfile'
autoload :YAML, 'yaml'
autoload :REXML, 'rexml/document'
autoload :XmlSimple, 'xmlsimple'
autoload :Builder, 'builder' # A different kind of buildr, one we use to create XML.
require 'erb'
require 'find'
require 'uri'
require 'stringio'
require 'fileutils'
require 'securerandom'

require 'buildr/core/util'
require 'buildr/core/console'
require 'buildr/core/common'
require 'buildr/core/application'
require 'buildr/core/project'
require 'buildr/core/assets'
require 'buildr/core/environment'
require 'buildr/core/help'
require 'buildr/core/build'
require 'buildr/core/filter'
require 'buildr/core/compile'
require 'buildr/core/test'
require 'buildr/java/commands'
require 'buildr/core/transports'
require 'buildr/java/pom'
require 'buildr/java/publish'
require 'buildr/core/doc'
require 'buildr/packaging/version_requirement'
require 'buildr/packaging/artifact_namespace'
require 'buildr/packaging/artifact'
require 'buildr/packaging/package'
require 'buildr/packaging/archive'
require 'buildr/packaging/ziptask'
require 'buildr/packaging/zip'
require 'buildr/java/compiler'
require 'buildr/java/tests'
require 'buildr/java/test_result'
require 'buildr/java/packaging'
require 'buildr/java/commands'
require 'buildr/java/doc'
require 'buildr/java/custom_pom'
require 'buildr/java/annotation_processor'
require 'buildr/ide/idea'

# Methods defined in Buildr are both instance methods (e.g. when included in Project)
# and class methods when invoked like Buildr.artifacts().
module Buildr ; extend self ; end

# The Buildfile object (self) has access to all the Buildr methods and constants.
class << self ; include Buildr ; end

# All modules defined under Buildr::* can be referenced without Buildr:: prefix
# unless a conflict exists (e.g.  Buildr::RSpec vs ::RSpec)
class Object #:nodoc:
  Buildr.constants.each do |name|
    const = Buildr.const_get(name)
    if const.is_a?(Module)
      const_set name, const unless const_defined?(name)
    end
  end
end
