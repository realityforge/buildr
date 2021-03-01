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

require 'yaml'

module Buildr #:nodoc:
  module TestFramework #:nodoc:

    # A class used by buildr for jruby based frameworks, so that buildr can know
    # which tests succeeded/failed.
    class TestResult

      class Error < ::Exception
        attr_reader :message, :backtrace
        def initialize(message, backtrace)
          @message = message
          @backtrace = backtrace
          set_backtrace backtrace
        end

        def self.dump_yaml(file, e)
          FileUtils.mkdir_p File.dirname(file)
          File.open(file, 'w') { |f| f.puts(YAML.dump(Error.new(e.message, e.backtrace))) }
        end

        def self.guard(file)
          begin
            yield
          rescue => e
            dump_yaml(file, e)
          end
        end
      end

      attr_accessor :failed, :succeeded

      def initialize
        @failed, @succeeded = [], []
      end
    end
  end
end
