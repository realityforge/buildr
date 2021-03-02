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


require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helpers'))

describe Buildr::TestNG do
  it 'should be selectable in project' do
    define 'foo' do
      test.using(:testng)
      test.framework.should eql(:testng)
    end
  end

  it 'should be selectable in parent project' do
    write 'bar/src/test/java/TestCase.java'
    define 'foo' do
      test.using(:testng)
      define 'bar'
    end
    project('foo:bar').test.framework.should eql(:testng)
  end

  it 'should parse test classes in paths containing escaped sequences' do
    write 'bar%2F/src/test/java/com/example/MyTest.java', <<-JAVA
      package com.example;
      @org.testng.annotations.Test
      public class MyTest {
        public void myTestMethod() { }
      }
    JAVA
    define 'foo' do
      define 'bar%2F' do
        test.using(:testng)
      end
    end
    project('foo:bar%2F').test.invoke
    project('foo:bar%2F').test.tests.should include('com.example.MyTest')
  end

  it 'should include classes using TestNG annotations' do
    write 'src/test/java/com/example/MyTest.java', <<-JAVA
      package com.example;
      @org.testng.annotations.Test
      public class MyTest {
        public void myTestMethod() { }
      }
    JAVA
    write 'src/test/java/com/example/MyOtherTest.java', <<-JAVA
      package com.example;
      public class MyOtherTest {
        @org.testng.annotations.Test
        public void annotated() { }
      }
    JAVA
    define('foo') { test.using(:testng) }
    project('foo').test.invoke
    project('foo').test.tests.should include('com.example.MyTest', 'com.example.MyOtherTest')
  end

  it 'should ignore classes not using TestNG annotations' do
    write 'src/test/java/NotATestClass.java', 'public class NotATestClass {}'
    define('foo') { test.using(:testng) }
    project('foo').test.invoke
    project('foo').test.tests.should be_empty
  end

  it 'should ignore abstract test classes' do
    write 'src/test/java/AbstractMyTest.java', 'public class AbstractMyTest {}'
    define('foo') { test.using(:testng) }
    project('foo').test.invoke
    project('foo').test.tests.should be_empty
  end

  it 'should ignore inner classes' do
    write 'src/test/java/InnerClassTest.java', <<-JAVA
      @org.testng.annotations.Test
      public class InnerClassTest {
        public void myTestMethod() { }

        public class InnerTest {
        }
      }
    JAVA
    define('foo') { test.using(:testng) }
    project('foo').test.invoke
    project('foo').test.tests.should eql(['InnerClassTest'])
  end

  it 'should pass when TestNG test case passes' do
    write 'src/test/java/PassingTest.java', <<-JAVA
      public class PassingTest {
        @org.testng.annotations.Test
        public void testNothing() {}
      }
    JAVA
    define('foo') { test.using(:testng) }
    lambda { project('foo').test.invoke }.should_not raise_error
  end

  it 'should fail when TestNG test case fails' do
    write 'src/test/java/FailingTest.java', <<-JAVA
      public class FailingTest {
        @org.testng.annotations.Test
        public void testNothing() {
          org.testng.AssertJUnit.assertTrue(false);
        }
      }
    JAVA
    define('foo') { test.using(:testng) }
    lambda { project('foo').test.invoke }.should raise_error(RuntimeError, /Tests failed/)
  end

  it 'should fail when TestNG test case fails to compile' do
    write 'src/test/java/FailingTest.java', <<-JAVA
      public class FailingTest exte lasjw9jc930d;kl;kl
    JAVA
    define('foo') { test.using(:testng) }
    lambda { project('foo').test.invoke }.should raise_error(RuntimeError)
  end

  it 'should fail when multiple TestNG test case fail' do
    write 'src/test/java/Failing1Test.java', <<-JAVA
      public class Failing1Test {
        @org.testng.annotations.Test
        public void testNothing() {
          org.testng.AssertJUnit.assertTrue(false);
        }
      }
    JAVA
    write 'src/test/java/Failing2Test.java', <<-JAVA
      public class Failing2Test {
        @org.testng.annotations.Test
        public void testNothing() {
          org.testng.AssertJUnit.assertTrue(false);
        }
      }
    JAVA
    define('foo') { test.using(:testng) }
    lambda { project('foo').test.invoke }.should raise_error(RuntimeError, /Tests failed/)
  end

  it 'should report failed test names' do
    write 'src/test/java/FailingTest.java', <<-JAVA
      public class FailingTest {
        @org.testng.annotations.Test
        public void testNothing() {
          org.testng.AssertJUnit.assertTrue(false);
        }
      }
    JAVA
    define('foo') { test.using(:testng) }
    project('foo').test.invoke rescue nil
    project('foo').test.failed_tests.should include('FailingTest')
  end

  it 'should report to reports/testng' do
    define('foo') { test.using(:testng) }
    project('foo').test.report_to.should be(project('foo').file('reports/testng'))
  end

  it 'should generate reports' do
    write 'src/test/java/PassingTest.java', <<-JAVA
      public class PassingTest {
        @org.testng.annotations.Test
        public void testNothing() {}
      }
    JAVA
    define('foo') { test.using(:testng) }
    lambda { project('foo').test.invoke }.should change { File.exist?('reports/testng/index.html') }.to(true)
  end

  it 'should include classes using TestNG annotations marked with a specific group' do
    write 'src/test/java/com/example/AnnotatedClass.java', <<-JAVA
      package com.example;
      @org.testng.annotations.Test(groups={"included"})
      public class AnnotatedClass { }
    JAVA
    write 'src/test/java/com/example/AnnotatedMethod.java', <<-JAVA
      package com.example;
      public class AnnotatedMethod {
        @org.testng.annotations.Test
        public void annotated() {
          org.testng.AssertJUnit.assertTrue(false);
        }
      }
    JAVA
    define('foo').test.using :testng, :groups=>['included']
    lambda { project('foo').test.invoke }.should_not raise_error
  end

  it 'should exclude classes using TestNG annotations marked with a specific group' do
    write 'src/test/java/com/example/AnnotatedClass.java', <<-JAVA
      package com.example;
      @org.testng.annotations.Test(groups={"excluded"})
      public class AnnotatedClass {
        public void annotated() {
          org.testng.AssertJUnit.assertTrue(false);
        }
      }
    JAVA
    write 'src/test/java/com/example/AnnotatedMethod.java', <<-JAVA
      package com.example;
      public class AnnotatedMethod {
        @org.testng.annotations.Test(groups={"included"})
        public void annotated() {}
      }
    JAVA
    define('foo').test.using :testng, :excludegroups=>['excluded']
    lambda { project('foo').test.invoke }.should_not raise_error
  end
end
