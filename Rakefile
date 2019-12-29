require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].reject do |path|
    path =~ %r{test/stdlib/}
  end
end

task :default => [:test, :stdlib_test, :rubocop, :validate]

task :validate do
  sh "rbs validate"
end

task :stdlib_test do
  sh "ruby bin/test_runner.rb"
end

task :rubocop do
  sh "rubocop --parallel"
end

rule ".rb" => ".y" do |t|
  sh "racc -v -o #{t.name} #{t.source}"
end

task :parser => "lib/ruby/signature/parser.rb"
task :test => :parser
task :stdlib_test => :parser
task :build => :parser

namespace :generate do
  desc 'Generate test file for stdlib'
  task :stdlib_test, [:class] do |_task, args|
    klass = args.fetch(:class) do
      raise "Class name is necessary. e.g. rake 'generate:stdlib_test[String]'"
    end

    path = Pathname("test/stdlib/#{klass}_test.rb")
    raise "#{path} already exists!" if path.exist?

    path.write <<~RUBY
      require_relative "test_helper"
      
      class #{klass}Test < StdlibTest
        target #{klass}
        # library "pathname", "set", "securerandom"     # Declare library signatures to load
        using hook.refinement

        # def test_method_name
        #   # Call the method
        #   method_name(arg)
        #   method_name(arg, arg2)
        # end
      end
    RUBY

    puts "Created: #{path}"
  end
end

task :writer_smoke_test do
  require 'ruby/signature'

  raise "stdlib/ has changes" unless system('git diff --exit-code --quiet stdlib/')

  begin
    Pathname.glob('stdlib/**/*.rbs').each do |path|
      sig = path.read
      path.open("w") do |f|
        w = Ruby::Signature::Writer.new(out: f)
        decls = Ruby::Signature::Parser.parse_signature(sig)
        w.write(decls)
      end
    end

    sh "ruby bin/test_runner.rb"
  ensure
    sh 'git checkout stdlib/'
  end
end

CLEAN.include("lib/ruby/signature/parser.rb")
