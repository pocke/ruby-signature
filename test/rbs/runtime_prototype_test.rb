require "test_helper"

class RBS::RuntimePrototypeTest < Minitest::Test
  Runtime = RBS::Prototype::Runtime
  DefinitionBuilder = RBS::DefinitionBuilder

  include TestHelper

  module TestTargets
    module Foo
      include Enumerable
    end

    class Test < String
      include Foo

      NAME = "Hello"

      def foo(foo, bar=1, *baz, a, b:, c: nil, **d)
      end

      alias bar foo

      private

      def a()
      end

      def self.baz(&block)
      end

      def self.b()
      end
    end
  end

  def test_1
    SignatureManager.new do |manager|
      manager.build do |env|
        p = Runtime.new(patterns: ["RBS::RuntimePrototypeTest::TestTargets::*"], env: env, merge: false)

        assert_write p.decls, <<-EOF
module RBS::RuntimePrototypeTest::TestTargets::Foo
  include Enumerable
end

class RBS::RuntimePrototypeTest::TestTargets::Test < String
  include Foo

  def self.b: () -> nil

  def self.baz: () ?{ (*untyped) -> untyped } -> nil

  public

  alias bar foo

  def foo: (untyped foo, ?untyped bar, *untyped baz, untyped a, b: untyped, ?c: untyped, **untyped) -> nil

  private

  def a: () -> nil
end

RBS::RuntimePrototypeTest::TestTargets::Test::NAME: String
    EOF
      end
    end 
  end

  def test_merge_types
    SignatureManager.new do |manager|
      manager.files[Pathname("foo.rbs")] = <<EOF
class RBS::RuntimePrototypeTest::TestTargets::Test
  def self.baz: () -> void

  def foo: (String) -> Integer
         | (String, bool) { () -> void } -> [Symbol]

  def bar: () -> void
end
EOF

      manager.build do |env|
        p = Runtime.new(patterns: ["RBS::RuntimePrototypeTest::TestTargets::*"], env: env, merge: true)

        assert_write p.decls, <<-EOF
module RBS::RuntimePrototypeTest::TestTargets::Foo
  include Enumerable
end

class RBS::RuntimePrototypeTest::TestTargets::Test < String
  include Foo

  def self.b: () -> nil

  def self.baz: () -> void

  public

  alias bar foo

  def foo: (String) -> Integer
         | (String, bool) { () -> void } -> [Symbol]

  private

  def a: () -> nil
end

RBS::RuntimePrototypeTest::TestTargets::Test::NAME: String
        EOF
      end
    end
  end

  module IncludeTests
    class SuperClass
      def foo; end
      def self.foo; end
    end

    class ChildClass < SuperClass
      def bar; end
    end
  end

  def test_include_owner
    SignatureManager.new do |manager|
      manager.build do |env|
        p = Runtime.new(patterns: ["RBS::RuntimePrototypeTest::IncludeTests::*"],
                        env: env,
                        merge: true,
                        owners_included: ["RBS::RuntimePrototypeTest::IncludeTests::SuperClass"])

        assert_write p.decls, <<-EOF
class RBS::RuntimePrototypeTest::IncludeTests::ChildClass < RBS::RuntimePrototypeTest::IncludeTests::SuperClass
  def self.foo: () -> nil

  public

  def bar: () -> nil

  def foo: () -> nil
end

class RBS::RuntimePrototypeTest::IncludeTests::SuperClass
  def self.foo: () -> nil

  public

  def foo: () -> nil
end
        EOF
      end
    end
  end
end
