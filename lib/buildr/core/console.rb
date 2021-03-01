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

module Buildr #nodoc

  # A utility class that helps with colorizing output for interactive shells where appropriate
  class Console
    class << self
      def use_color
        @use_color.nil? ? false : @use_color
      end

      def use_color=(use_color)
        return if use_color && !setup_support
        @use_color = use_color
      end

      # Emit message with color at the start of the message and the clear color command at the end of the sequence.
      def color(message, color)
        raise "Unknown color #{color.inspect}" unless [:green, :red, :blue].include?(color)
        return message unless use_color
        constants = {:green => "\e[32m", :red => "\e[31m", :blue => "\e[34m"}
        @java_console.putString("#{constants[color]}#{message}\e[0m") if @java_console
        "#{constants[color]}#{message}\e[0m"
      end

      # Return the [rows, columns] of a console or nil if unknown
      def console_dimensions
        return nil unless setup_support

        begin
          if Buildr::Util.win_os?
              Win32::Console.new(Win32::Console::STD_OUTPUT_HANDLE).MaxWindow
          elsif $stdout.isatty
            if /solaris/ =~ RUBY_PLATFORM and
              `stty` =~ /\brows = (\d+).*\bcolumns = (\d+)/
              [$2, $1].map { |c| x.to_i }
            else
              `stty size 2> /dev/null`.split.map { |x| x.to_i }.reverse
            end
          else
            nil
          end
        rescue => e
          nil
        end
      end

      # Return the number of columns in console or nil if unknown
      def output_cols
        d = console_dimensions
        d ? d[0] : nil
      end

      def agree?(message)
        puts "#{message} (Y or N)"
        :agree == ask('Y' => :agree, 'N' => :disagree)
      end

      def ask_password(prompt)
        puts prompt
        begin
          set_no_echo_mode
          password = $stdin.readline
          return password.chomp
        ensure
          reset_mode
        end
      end

      def present_menu(header, options)
        puts header
        question_options = {}
        count = 1
        options.each_pair do |message, result|
          puts "#{count}. #{message}"
          question_options[count.to_s] = result
          count += 1
        end
        ask(question_options)
      end

      private

      def set_no_echo_mode
        return unless setup_support
        if Buildr::Util.win_os?
          c = Win32::Console.new(Win32::Console::STD_OUTPUT_HANDLE)
          c.Echo(false) rescue Exception
        else
          @state = `stty -g 2>/dev/null`
          `stty -echo -icanon 2>/dev/null`
        end
      end

      def reset_mode
        return unless setup_support
        if Buildr::Util.win_os?
          c = Win32::Console.new(Win32::Console::STD_OUTPUT_HANDLE)
          c.Echo(true) rescue Exception
        else
          `stty #{@state} 2>/dev/null`
        end
        @state = nil
      end

      def ask(options)
        keys = options.keys
        keys_downcased = keys.collect { |k| k.downcase }
        result = nil
        show_prompt = false
        until keys_downcased.include?(result)
          puts "Invalid response. Valid responses include: #{keys.join(', ')}\n" if show_prompt
          show_prompt = true
          result = $stdin.readline
          result = result.strip.downcase if result
        end
        options.each_pair do |key, value|
          if key.downcase == result
            return value.is_a?(Proc) ? value.call : value
          end
        end
        return nil
      end

      def setup_support
        return @initialized unless @initialized.nil?
        @initialized = false
        begin
          if Buildr::Util.win_os?
            require 'Win32/Console/ANSI'
          end
        rescue
          # Unfortunately we have multiple incompatible jline libraries
          # in the classpath. This is probably because we are using jruby
          # 1.7.5 with a library like scala and both use incompatible jline
          # implementations
          return false
        rescue NameError
          return false
        rescue LoadError
          return false
        end
        @initialized = true
        return true
      end

    end
  end
end

Buildr::Console.use_color = $stdout.isatty
