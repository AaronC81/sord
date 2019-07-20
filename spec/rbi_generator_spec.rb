# typed: ignore
require 'yard'

describe Sord::RbiGenerator do
  before do
    YARD::Registry.clear
    Sord::Logging.silent = true
  end

  subject do
    # Create an unnamed class to emulate everything required in "options"
    Sord::RbiGenerator.new(
      comments: true,
      break_params: 4,
      replace_errors_with_untyped: false,
      replace_unresolved_with_untyped: false
    )
  end

  def fix_heredoc(x)
    lines = x.lines
    /^( *)/ === lines.first
    indent_amount = $1.length
    lines.map do |line|
      /^ +$/ === line[0...indent_amount] \
        ? line[indent_amount..-1]
        : line
    end.join.rstrip
  end

  it 'handles blank registries' do
    expect(subject.generate.strip).to eq "# typed: strong"
  end

  it 'handles blank module structures' do
    YARD.parse_string(<<-RUBY)
      module A
        module B; end
        module C
          module D; end
        end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        module B
        end

        module C
          module D
          end
        end
      end
    RUBY
  end

  it 'handles structures with modules, classes and methods' do
    YARD.parse_string(<<-RUBY)
      module A
        class B
          # @return [Integer]
          def foo; end
        end
        module C
          class D
            # @param [String] x
            # @return [void]
            def bar(x); end
          end
        end
        module E
        end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        class B
          sig { returns(Integer) }
          def foo; end
        end

        module C
          class D
            sig { params(x: String).void }
            def bar(x); end
          end
        end

        module E
        end
      end
      RUBY
  end
  
  it 'auto-generates T.untyped signatures when unspecified and warns' do
    YARD.parse_string(<<-RUBY)
      module A
        class B
          def foo; end
        end
        module C
          class D
            def bar(x); end
          end
        end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        class B
          # sord omit - no YARD return type given, using T.untyped
          sig { returns(T.untyped) }
          def foo; end
        end

        module C
          class D
            # sord omit - no YARD type given for "x", using T.untyped
            # sord omit - no YARD return type given, using T.untyped
            sig { params(x: T.untyped).returns(T.untyped) }
            def bar(x); end
          end
        end
      end
      RUBY
  end

  it 'generates inheritance, inclusion and extension' do
    YARD.parse_string(<<-RUBY)
      class A; end
      class B; end
      class C; end

      class D < A
        include B
        extend C
        def x; end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
      end

      class B
      end

      class C
      end

      class D < A
        include B
        extend C

        # sord omit - no YARD return type given, using T.untyped
        sig { returns(T.untyped) }
        def x; end
      end
    RUBY
  end

  it 'generates includes in the same order as they were in the original file' do
    YARD.parse_string(<<-EOF)
      class A; end
      class B; end
      class C; end

      class D < A
        include C
        include B
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      class A
      end

      class B
      end

      class C
      end

      class D < A
        include C
        include B
      end
    EOF
  end


  it 'generates extends in the same order as they were in the original file' do
    YARD.parse_string(<<-EOF)
      class A; end
      class B; end
      class C; end

      class D < A
        extend C
        extend B
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      class A
      end

      class B
      end

      class C
      end

      class D < A
        extend C
        extend B
      end
    EOF
  end

  it 'generates blocks correctly' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [String] x
        # @return [Boolean]
        # @yieldparam [Integer] a
        # @yieldparam [Float] b
        # @yieldreturn [Boolean] c
        def foo(x, &blk); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { params(x: String, blk: T.proc.params(a: Integer, b: Float).returns(T::Boolean)).returns(T::Boolean) }
        def foo(x, &blk); end
      end
    RUBY
  end

  it 'handles void yieldreturn' do
    YARD.parse_string(<<-RUBY)
      module A
        # @yieldparam [Symbol] foo
        # @yieldreturn [void]
        # @return [void]
        def self.foo(&blk); end
      end
    RUBY
  
    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { params(blk: T.proc.params(foo: Symbol).void).void }
        def self.foo(&blk); end
      end
    RUBY
  end

  it 'generates varargs correctly' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [Integer] x
        # @param [Array<String>] y
        # @return [void]
        def foo(x, *y); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { params(x: Integer, y: T::Array[String]).void }
        def foo(x, *y); end
      end
    RUBY
  end

  it 'breaks parameters across multiple lines correctly' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [Integer] a
        # @param [String] b
        # @param [Float] c
        # @param [Object] d
        # @return [void]
        def foo(a, b, c, d); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig do
          params(
            a: Integer,
            b: String,
            c: Float,
            d: Object
          ).void
        end
        def foo(a, b, c, d); end
      end
    RUBY
  end

  it 'infers setter types' do
    YARD.parse_string(<<-RUBY)
      module A
        # @return [Integer]
        def x; end

        def x=(value); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { returns(Integer) }
        def x; end

        # sord infer - inferred type of parameter "value" as Integer using getter's return type
        # sord omit - no YARD return type given, using T.untyped
        sig { params(value: Integer).returns(T.untyped) }
        def x=(value); end
      end
    RUBY
  end

  it 'infers one missing argument name in standard methods' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [String]
        # @return [void]
        def x(a); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord infer - argument name in single @param inferred as "a"
        sig { params(a: String).void }
        def x(a); end
      end
    RUBY
  end

  it 'infers one missing argument name in setters' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [String]
        # @return [String]
        attr_writer :x
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord infer - argument name in single @param inferred as "value"
        sig { params(value: String).returns(String) }
        def x=(value); end
      end
    RUBY
  end

  it 'uses T.untyped for many missing argument names' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [String] 
        # @param [Integer] b
        # @param [Boolean]
        # @return [void]
        def x(a, b, c); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord omit - no YARD type given for "a", using T.untyped
        # sord omit - no YARD type given for "c", using T.untyped
        sig { params(a: T.untyped, b: Integer, c: T.untyped).void }
        def x(a, b, c); end
      end
    RUBY
  end

  it 'does not include inherited methods in its output' do
    YARD.parse_string(<<-RUBY)
      class A
        # @return [void]
        def x; end
      end

      class B < A
        # @return [void]
        def y; end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        sig { void }
        def x; end
      end

      class B < A
        sig { void }
        def y; end
      end
    RUBY
  end

  it 'marks variables with default nil as nilable' do
    YARD.parse_string(<<-RUBY)
      class A
        # @param [String] a
        # @return [void]
        def x(a: nil, b: nil); end
  
        # @param [String] a
        # @return [void]
        def y(a = nil); end
  
        # @param [String, nil] a
        # @return [void]
        def z(a = nil); end
      end
    RUBY
  
    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # sord omit - no YARD type given for "b:", using T.untyped
        sig { params(a: T.nilable(String), b: T.untyped).void }
        def x(a: nil, b: nil); end

        sig { params(a: T.nilable(String)).void }
        def y(a = nil); end

        sig { params(a: T.nilable(String)).void }
        def z(a = nil); end
      end
    RUBY
  end

  it 'correctly parses methods with all kinds of parameters' do
    YARD.parse_string(<<-RUBY)
      class A
        # @param [String] a
        # @param [String] b
        # @param [String] c
        # @param [String] d
        # @return [void]
        def x(a, b = 'Foo', c: 'Bar', d:); end
      end
    RUBY

    expect(subject.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        sig do
          params(
            a: String,
            b: String,
            c: String,
            d: String
          ).void
        end
        def x(a, b = 'Foo', c: 'Bar', d:); end
      end
    RUBY
  end
end
