# typed: ignore
require 'yard'

describe Sord::Generator do
  before do
    YARD::Registry.clear
    Sord::Logging.silent = true
    YARD::Logger.instance.level = Logger::ERROR
  end

  COMMON_OPTIONS = {
    sord_comments: true,
    break_params: 4,
    replace_errors_with_untyped: false,
    replace_unresolved_with_untyped: false,
    keep_original_comments: false
  }

  def rbi_gen(**extra_options)
    Sord::Generator.new(mode: :rbi, **COMMON_OPTIONS.merge(extra_options))
  end

  def rbs_gen(**extra_options)
    Sord::Generator.new(mode: :rbs, **COMMON_OPTIONS.merge(extra_options))
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
    expect(rbi_gen.generate.strip).to eq "# typed: strong"
    expect(rbs_gen.generate.strip).to eq ""
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
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

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        class B
          sig { returns(Integer) }
          def foo; end
        end

        module C
          class D
            # _@param_ `x`
            sig { params(x: String).void }
            def bar(x); end
          end
        end

        module E
        end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        class B
          def foo: () -> Integer
        end

        module C
          class D
            # _@param_ `x`
            def bar: (String x) -> void
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        class B
          # sord omit - no YARD return type given, using untyped
          sig { returns(T.untyped) }
          def foo; end
        end

        module C
          class D
            # sord omit - no YARD type given for "x", using untyped
            # sord omit - no YARD return type given, using untyped
            sig { params(x: T.untyped).returns(T.untyped) }
            def bar(x); end
          end
        end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        class B
          # sord omit - no YARD return type given, using untyped
          def foo: () -> untyped
        end

        module C
          class D
            # sord omit - no YARD type given for "x", using untyped
            # sord omit - no YARD return type given, using untyped
            def bar: (untyped x) -> untyped
          end
        end
      end
    RUBY
  end

  it 'hides private objects when using @hide_private' do
    YARD.parse_string(<<-RUBY)
      module A
        class B
          # @return [String]
          def foo; end

          # @!visibility private
          CONST_NAME = "something"

          # @!visibility private
          attr_accessor :some_attr

          # @!visibility private
          def foo?; end
        end
        # @!visibility private
        module C
          class D
            def bar(x); end

            attr_accessor :baz
          end
        end
      end
    RUBY

    expect(rbi_gen(hide_private: true).generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        class B
          sig { returns(String) }
          def foo; end
        end
      end
    RUBY

    expect(rbs_gen(hide_private: true).generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        class B
          def foo: () -> String
        end
      end
    RUBY
  end

  it 'excludes untyped methods when using @exclude_untyped' do
    YARD.parse_string(<<-RUBY)
      module A
        class B
          def foo; end

          # @return [Boolean]
          def foo?; end
        end
        module C
          class D
            def bar(x); end

            attr_accessor :baz
          end
        end
      end
    RUBY

    expect(rbi_gen(exclude_untyped: true).generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        class B
          # sord omit - excluding untyped

          sig { returns(T::Boolean) }
          def foo?; end
        end

        module C
          class D
            # sord omit - excluding untyped

            # sord omit - excluding untyped attribute
          end
        end
      end
    RUBY

    expect(rbs_gen(exclude_untyped: true).generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        class B
          # sord omit - excluding untyped

          def foo?: () -> bool
        end

        module C
          class D
            # sord omit - excluding untyped
      
            # sord omit - excluding untyped attribute
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
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

        # sord omit - no YARD return type given, using untyped
        sig { returns(T.untyped) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
      end

      class B
      end

      class C
      end

      class D < A
        include B
        extend C

        # sord omit - no YARD return type given, using untyped
        def x: () -> untyped
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-EOF)
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

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-EOF)
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-EOF)
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

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-EOF)
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # _@param_ `x`
        sig { params(x: String, blk: T.proc.params(a: Integer, b: Float).returns(T::Boolean)).returns(T::Boolean) }
        def foo(x, &blk); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # _@param_ `x`
        def foo: (String x) ?{ (Integer a, Float b) -> bool } -> bool
      end
    RUBY
  end

  it 'generates unnamed blocks correctly' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [String] x
        # @return [Boolean]
        # @yieldparam [Integer] a
        # @yieldparam [Float] b
        # @yieldreturn [Boolean] c
        def foo(x)
          yield(1, 2.0, true)
        end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # _@param_ `x`
        sig { params(x: String, blk: T.proc.params(a: Integer, b: Float).returns(T::Boolean)).returns(T::Boolean) }
        def foo(x, &blk); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # _@param_ `x`
        def foo: (String x) ?{ (Integer a, Float b) -> bool } -> bool
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { params(blk: T.proc.params(foo: Symbol).void).void }
        def self.foo(&blk); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        def self.foo: () ?{ (Symbol foo) -> void } -> void
      end
    RUBY
  end

  it 'handles missing block parameter names' do
    YARD.parse_string(<<-RUBY)
      module A
        # @yieldparam [Symbol]
        # @yieldparam [String]
        # @yieldreturn [void]
        # @return [void]
        def self.foo(&blk); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { params(blk: T.proc.params(arg0: Symbol, arg1: String).void).void }
        def self.foo(&blk); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        def self.foo: () ?{ (Symbol arg0, String arg1) -> void } -> void
      end
    RUBY
  end

  it 'handle multiline comment correctly' do
    YARD.parse_string(<<-RUBY)
      module A
        # @param [Integer] x
        # @param [Array<String>] y
        # @return [void] comment with multiple
        #   line
        def foo(x, *y); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # _@param_ `x`
        # 
        # _@param_ `y`
        # 
        # _@return_ — comment with multiple
        # line
        sig { params(x: Integer, y: T::Array[String]).void }
        def foo(x, *y); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # _@param_ `x`
        # 
        # _@param_ `y`
        # 
        # _@return_ — comment with multiple
        # line
        def foo: (Integer x, *::Array[String] y) -> void
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # _@param_ `x`
        # 
        # _@param_ `y`
        sig { params(x: Integer, y: T::Array[String]).void }
        def foo(x, *y); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # _@param_ `x`
        # 
        # _@param_ `y`
        def foo: (Integer x, *::Array[String] y) -> void
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # _@param_ `a`
        # 
        # _@param_ `b`
        # 
        # _@param_ `c`
        # 
        # _@param_ `d`
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

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # _@param_ `a`
        # 
        # _@param_ `b`
        # 
        # _@param_ `c`
        # 
        # _@param_ `d`
        def foo: (
                   Integer a,
                   String b,
                   Float c,
                   Object d
                 ) -> void
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        sig { returns(Integer) }
        def x; end

        # sord infer - inferred type of parameter "value" as Integer using getter's return type
        # sord omit - no YARD return type given, using untyped
        sig { params(value: Integer).returns(T.untyped) }
        def x=(value); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        def x: () -> Integer

        # sord infer - inferred type of parameter "value" as Integer using getter's return type
        # sord omit - no YARD return type given, using untyped
        def x=: (Integer value) -> untyped
      end
    RUBY
  end

  it 'does not attempt inference when there is no setter type' do
    YARD.parse_string(<<-RUBY)
      module A
        def x; end

        def x=(value); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord omit - no YARD return type given, using untyped
        sig { returns(T.untyped) }
        def x; end

        # sord omit - no YARD type given for "value", using untyped
        # sord omit - no YARD return type given, using untyped
        sig { params(value: T.untyped).returns(T.untyped) }
        def x=(value); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # sord omit - no YARD return type given, using untyped
        def x: () -> untyped

        # sord omit - no YARD type given for "value", using untyped
        # sord omit - no YARD return type given, using untyped
        def x=: (untyped value) -> untyped
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord infer - argument name in single @param inferred as "a"
        sig { params(a: String).void }
        def x(a); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # sord infer - argument name in single @param inferred as "a"
        def x: (String a) -> void
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "c", using untyped
        # _@param_ `b`
        sig { params(a: T.untyped, b: Integer, c: T.untyped).void }
        def x(a, b, c); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "c", using untyped
        # _@param_ `b`
        def x: (untyped a, Integer b, untyped c) -> void
      end
    RUBY
  end

  it 'merges tags from overridden methods' do
    YARD.parse_string(<<-RUBY)
      class A
        # @param a [String]
        def x(a); end

        def y(a); end
      end

      class B < A
        # @return [Boolean]
        def x(a); end

        # @param a [String]
        def y(a); end        
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # sord omit - no YARD return type given, using untyped
        # _@param_ `a`
        sig { params(a: String).returns(T.untyped) }
        def x(a); end
      
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD return type given, using untyped
        sig { params(a: T.untyped).returns(T.untyped) }
        def y(a); end
      end

      class B < A
        sig { params(a: String).returns(T::Boolean) }
        def x(a); end
      
        # sord omit - no YARD return type given, using untyped
        # _@param_ `a`
        sig { params(a: String).returns(T.untyped) }
        def y(a); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        # sord omit - no YARD return type given, using untyped
        # _@param_ `a`
        def x: (String a) -> untyped
      
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD return type given, using untyped
        def y: (untyped a) -> untyped
      end

      class B < A
        def x: (String a) -> bool
      
        # sord omit - no YARD return type given, using untyped
        # _@param_ `a`
        def y: (String a) -> untyped
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
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

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        def x: () -> void
      end

      class B < A
        def y: () -> void
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

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # sord omit - no YARD type given for "b:", using untyped
        # _@param_ `a`
        sig { params(a: T.nilable(String), b: T.untyped).void }
        def x(a: nil, b: nil); end

        # _@param_ `a`
        sig { params(a: T.nilable(String)).void }
        def y(a = nil); end

        # _@param_ `a`
        sig { params(a: T.nilable(String)).void }
        def z(a = nil); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        # sord omit - no YARD type given for "b:", using untyped
        # _@param_ `a`
        def x: (?a: String?, ?b: untyped) -> void

        # _@param_ `a`
        def y: (?String? a) -> void

        # _@param_ `a`
        def z: (?String? a) -> void
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
        def x(a, b = 'Foo', c:, d: 'Bar'); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # _@param_ `a`
        # 
        # _@param_ `b`
        # 
        # _@param_ `c`
        # 
        # _@param_ `d`
        sig do
          params(
            a: String,
            b: String,
            c: String,
            d: String
          ).void
        end
        def x(a, b = 'Foo', c:, d: 'Bar'); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        # _@param_ `a`
        # 
        # _@param_ `b`
        # 
        # _@param_ `c`
        # 
        # _@param_ `d`
        def x: (
                 String a,
                 ?String b,
                 c: String,
                 ?d: String
               ) -> void
      end
    RUBY
  end

  it 'handles untyped generics' do
    YARD.parse_string(<<-RUBY)
      class A
        # @param [Array] array
        # @param [Hash] hash
        # @param [Range] range
        # @param [Set] set
        # @param [Enumerator] enumerator
        # @param [Enumerable] enumerable
        # @return [void]
        def x(array, hash, range, set, enumerator, enumerable); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # _@param_ `array`
        # 
        # _@param_ `hash`
        # 
        # _@param_ `range`
        # 
        # _@param_ `set`
        # 
        # _@param_ `enumerator`
        # 
        # _@param_ `enumerable`
        sig do
          params(
            array: T::Array[T.untyped],
            hash: T::Hash[T.untyped, T.untyped],
            range: T::Range[T.untyped],
            set: T::Set[T.untyped],
            enumerator: T::Enumerator[T.untyped],
            enumerable: T::Enumerable[T.untyped]
          ).void
        end
        def x(array, hash, range, set, enumerator, enumerable); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        # _@param_ `array`
        # 
        # _@param_ `hash`
        # 
        # _@param_ `range`
        # 
        # _@param_ `set`
        # 
        # _@param_ `enumerator`
        # 
        # _@param_ `enumerable`
        def x: (
                 ::Array[untyped] array,
                 ::Hash[untyped, untyped] hash,
                 ::Range[untyped] range,
                 ::Set[untyped] set,
                 ::Enumerator[untyped] enumerator,
                 ::Enumerable[untyped] enumerable
               ) -> void
      end
    RUBY
  end

  it 'returns fully qualified superclasses' do
    YARD.parse_string(<<-RUBY)
      class Alphabet
      end
  
      class Letters < Alphabet
      end
  
      class A < Alphabet::Letters
        # @return [void]
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class Alphabet
      end
      
      class Letters < Alphabet
      end
      
      class A < Alphabet::Letters
        sig { void }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class Alphabet
      end
      
      class Letters < Alphabet
      end
      
      class A < Alphabet::Letters
        def x: () -> void
      end
    RUBY
  end

  it 'handles constants' do
    YARD.parse_string(<<-RUBY)
      class A
        EXAMPLE_UNTYPED_CONSTANT = 'Foo'
        # @return [String]
        EXAMPLE_TYPED_CONSTANT = 'Bar'
        EXAMPLE_UNTYPED_CONSTANT_WITH_HEREDOC = <<END
Baz
END
        # @return [String]
        EXAMPLE_TYPED_CONSTANT_WITH_HEREDOC = <<END
Bing
END
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        EXAMPLE_UNTYPED_CONSTANT = T.let('Foo', T.untyped)
        EXAMPLE_TYPED_CONSTANT = T.let('Bar', T.untyped)
        EXAMPLE_UNTYPED_CONSTANT_WITH_HEREDOC = T.let(<<END, T.untyped)
Baz
END
        EXAMPLE_TYPED_CONSTANT_WITH_HEREDOC = T.let(<<END, T.untyped)
Bing
END
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        EXAMPLE_UNTYPED_CONSTANT: untyped
        EXAMPLE_TYPED_CONSTANT: String
        EXAMPLE_UNTYPED_CONSTANT_WITH_HEREDOC: untyped
        EXAMPLE_TYPED_CONSTANT_WITH_HEREDOC: String
      end
    RUBY
  end

  it 'does not generate constants from included classes' do
    YARD.parse_string(<<-RUBY)
      class A
        EXAMPLE_CONSTANT = 'Foo'
      end

      class B
        include A
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        EXAMPLE_CONSTANT = T.let('Foo', T.untyped)
      end

      class B
        include A
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        EXAMPLE_CONSTANT: untyped
      end

      class B
        include A
      end
    RUBY
  end

  it 'correctly generates constants in nested classes' do
    YARD.parse_string(<<-RUBY)
      class A
        class B
          EXAMPLE_CONSTANT = 'Foo'
        end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        class B
          EXAMPLE_CONSTANT = T.let('Foo', T.untyped)
        end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        class B
          EXAMPLE_CONSTANT: untyped
        end
      end
    RUBY
  end

  it 'handles method with a long description' do
    YARD.parse_string(<<-RUBY)
      module A
        # Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
        # eiusmod tempor incididunt ut labore et dolore magna aliqua. Diam
        # quis enim lobortis scelerisque fermentum dui faucibus in. Id diam
        # vel quam elementum pulvinar etiam non. Egestas erat imperdiet sed
        # euismod nisi.
        #
        # @return [String]
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
        # eiusmod tempor incididunt ut labore et dolore magna aliqua. Diam
        # quis enim lobortis scelerisque fermentum dui faucibus in. Id diam
        # vel quam elementum pulvinar etiam non. Egestas erat imperdiet sed
        # euismod nisi.
        sig { returns(String) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
        # eiusmod tempor incididunt ut labore et dolore magna aliqua. Diam
        # quis enim lobortis scelerisque fermentum dui faucibus in. Id diam
        # vel quam elementum pulvinar etiam non. Egestas erat imperdiet sed
        # euismod nisi.
        def x: () -> String
      end
    RUBY
  end

  it 'handles method with examples and description' do
    YARD.parse_string(<<-RUBY)
      module A
        # This method returns a string.
        #
        # @example 
        #   A.x #=> foo
        #
        # @example
        #   A.x #=> bar
        #
        # @return [String]
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # This method returns a string.
        # 
        # ```ruby
        # A.x #=> foo
        # ```
        # 
        # ```ruby
        # A.x #=> bar
        # ```
        sig { returns(String) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # This method returns a string.
        # 
        # ```ruby
        # A.x #=> foo
        # ```
        # 
        # ```ruby
        # A.x #=> bar
        # ```
        def x: () -> String
      end
    RUBY
  end

  it 'handles method with a named example' do
    YARD.parse_string(<<-RUBY)
      module A
        # This method returns a string.
        #
        # @example This is a named example.
        #   A.x #=> foo
        #
        # @return [String]
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # This method returns a string.
        # 
        # This is a named example.
        # ```ruby
        # A.x #=> foo
        # ```
        sig { returns(String) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # This method returns a string.
        # 
        # This is a named example.
        # ```ruby
        # A.x #=> foo
        # ```
        def x: () -> String
      end
    RUBY
  end

  it 'handles method with a multi-line example' do
    YARD.parse_string(<<-RUBY)
      module A
        # @example
        #   # This example has multiple lines
        #   A.x
        #   #=> foo
        #
        # @return [String]
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # ```ruby
        # # This example has multiple lines
        # A.x
        # #=> foo
        # ```
        sig { returns(String) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # ```ruby
        # # This example has multiple lines
        # A.x
        # #=> foo
        # ```
        def x: () -> String
      end
    RUBY
  end

  it 'handles method with only an example' do
    YARD.parse_string(<<-RUBY)
      module A
        # @example
        #   A.x #=> foo
        #
        # @return [String]
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # ```ruby
        # A.x #=> foo
        # ```
        sig { returns(String) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # ```ruby
        # A.x #=> foo
        # ```
        def x: () -> String
      end
    RUBY
  end

  it 'handles method with parameters' do
    YARD.parse_string(<<-RUBY)
      module A
        # Lorem ipsum dolor.
        #
        # @param a [String] Lorem ipsum
        # @param b [String] Lorem ipsum
        #
        # @return [String]
        def x(a, b); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # Lorem ipsum dolor.
        # 
        # _@param_ `a` — Lorem ipsum
        # 
        # _@param_ `b` — Lorem ipsum
        sig { params(a: String, b: String).returns(String) }
        def x(a, b); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # Lorem ipsum dolor.
        # 
        # _@param_ `a` — Lorem ipsum
        # 
        # _@param_ `b` — Lorem ipsum
        def x: (String a, String b) -> String
      end
    RUBY
  end

  it 'handles method with multi-line parameter tag' do
    YARD.parse_string(<<-RUBY)
      module A
        # Lorem ipsum dolor.
        #
        # @param a [String] Lorem ipsum dolor
        #   sit amet.
        #
        # @return [String]
        def x(a); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # Lorem ipsum dolor.
        # 
        # _@param_ `a` — Lorem ipsum dolor sit amet.
        sig { params(a: String).returns(String) }
        def x(a); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # Lorem ipsum dolor.
        # 
        # _@param_ `a` — Lorem ipsum dolor sit amet.
        def x: (String a) -> String
      end
    RUBY
  end

  it 'handles methods with @note, @see, and @deprecated' do
    YARD.parse_string(<<-RUBY)
      module A
        # Lorem ipsum dolor.
        #
        # @deprecated You shouldn't use this method.
        #
        # @return [void]
        def x; end

        # Lorem ipsum dolor.
        #
        # @note This is a note.
        #
        # @return [void]
        def y; end

        # Lorem ipsum dolor.
        #
        # @see B Another letter.
        #
        # @return [void]
        def z; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # Lorem ipsum dolor.
        # 
        # _@deprecated_ — You shouldn't use this method.
        sig { void }
        def x; end

        # Lorem ipsum dolor.
        # 
        # _@note_ — This is a note.
        sig { void }
        def y; end

        # Lorem ipsum dolor.
        # 
        # _@see_ `B` — Another letter.
        sig { void }
        def z; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # Lorem ipsum dolor.
        # 
        # _@deprecated_ — You shouldn't use this method.
        def x: () -> void

        # Lorem ipsum dolor.
        # 
        # _@note_ — This is a note.
        def y: () -> void

        # Lorem ipsum dolor.
        # 
        # _@see_ `B` — Another letter.
        def z: () -> void
      end
    RUBY
  end

  it 'handles methods with @return descriptions' do
    YARD.parse_string(<<-RUBY)
      module A
        # Gets the example string.
        #
        # @return [String] The example string.
        def x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # Gets the example string.
        # 
        # _@return_ — The example string.
        sig { returns(String) }
        def x; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # Gets the example string.
        # 
        # _@return_ — The example string.
        def x: () -> String
      end
    RUBY
  end

  it 'reorders method parameters correctly' do
    YARD.parse_string(<<-RUBY)
      module A
        def x(a, b: [], c:, **rest, &blk); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "b:", using untyped
        # sord omit - no YARD type given for "c:", using untyped
        # sord omit - no YARD type given for "**rest", using untyped
        # sord omit - no YARD return type given, using untyped
        sig do
          params(
            a: T.untyped,
            b: T.untyped,
            c: T.untyped,
            rest: T.untyped,
            blk: T.untyped
          ).returns(T.untyped)
        end
        def x(a, b: [], c:, **rest, &blk); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "b:", using untyped
        # sord omit - no YARD type given for "c:", using untyped
        # sord omit - no YARD type given for "**rest", using untyped
        # sord omit - no YARD return type given, using untyped
        def x: (
                 untyped a,
                 ?b: untyped,
                 c: untyped,
                 **untyped rest
               ) -> untyped
      end
    RUBY
  end

  it 'doesn\'t mess with ordered parameters' do
    YARD.parse_string(<<-RUBY)
      module A
        def x(a, b = nil, c = nil, d: nil); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      module A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "b", using untyped
        # sord omit - no YARD type given for "c", using untyped
        # sord omit - no YARD type given for "d:", using untyped
        # sord omit - no YARD return type given, using untyped
        sig do
          params(
            a: T.untyped,
            b: T.untyped,
            c: T.untyped,
            d: T.untyped
          ).returns(T.untyped)
        end
        def x(a, b = nil, c = nil, d: nil); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      module A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "b", using untyped
        # sord omit - no YARD type given for "c", using untyped
        # sord omit - no YARD type given for "d:", using untyped
        # sord omit - no YARD return type given, using untyped
        def x: (
                 untyped a,
                 ?untyped b,
                 ?untyped c,
                 ?d: untyped
               ) -> untyped
      end
    RUBY
  end

  context 'attributes' do
    it 'are generated correctly with typical tags' do
      YARD.parse_string(<<-RUBY)
        module A
          # @return [Integer]
          attr_reader :x

          # @return [String]
          attr_writer :y

          # @return [Boolean]
          attr_accessor :z
        end
      RUBY

      expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        module A
          sig { returns(Integer) }
          attr_reader :x

          sig { params(y: String).returns(String) }
          attr_writer :y

          sig { returns(T::Boolean) }
          attr_accessor :z
        end
      RUBY

      expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        module A
          attr_reader x: Integer

          attr_writer y: String

          attr_accessor z: bool
        end
      RUBY
    end

    it 'can be on the class' do
      YARD.parse_string(<<-RUBY)
        module A
          class << self
            # @return [Integer]
            attr_reader :x
            
            # @return [String]
            attr_writer :y
            
            # @return [Float]
            attr_accessor :z
          end
        end
      RUBY

      expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        module A
          class << self
            sig { returns(Integer) }
            attr_reader :x

            sig { params(y: String).returns(String) }
            attr_writer :y

            sig { returns(Float) }
            attr_accessor :z
          end
        end
      RUBY

      expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        module A
          def self.x: () -> Integer

          def self.y=: (String value) -> String

          def self.z: () -> Float

          def self.z=: (Float value) -> Float
        end
      RUBY
    end

    it 'can share names between class and instance' do
      YARD.parse_string(<<-RUBY)
        module A
          class << self
            # @return [Integer]
            attr_reader :x
          end

          # @return [String]
          attr_reader :x
        end
      RUBY

      expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        module A
          class << self
            sig { returns(Integer) }
            attr_reader :x
          end

          sig { returns(String) }
          attr_reader :x
        end
      RUBY

      expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        module A
          def self.x: () -> Integer

          attr_reader x: String
        end
      RUBY
    end

    it 'handles void returns' do
      YARD.parse_string(<<-RUBY)
        module A
          # @param [String]
          # @return [void]
          attr_reader :x
        end
      RUBY

      expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        module A
          sig { returns(String) }
          attr_reader :x
        end
      RUBY

      expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        module A
          attr_reader x: String
        end
      RUBY
    end

    it 'preserve comments' do
      YARD.parse_string(<<-RUBY)
        module A
          # Gets the value of X.
          # @param [String]
          # @return [void]
          attr_reader :x
        end
      RUBY

      expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        # typed: strong
        module A
          # Gets the value of X.
          sig { returns(String) }
          attr_reader :x
        end
      RUBY

      expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
        module A
          # Gets the value of X.
          attr_reader x: String
        end
      RUBY
    end
  end

  it 'generates constructors which return void' do
    YARD.parse_string(<<-RUBY)
      class A
        # @param [String] a
        # @return [A]
        def initialize(a); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # _@param_ `a`
        sig { params(a: String).void }
        def initialize(a); end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        # _@param_ `a`
        def initialize: (String a) -> void
      end
    RUBY
  end

  it 'handles nil returns as if they were void' do
    YARD.parse_string(<<-RUBY)
      class A
        # @return [nil]
        def foo; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        sig { void }
        def foo; end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        def foo: () -> void
      end
    RUBY
  end

  it 'handles nil attributes' do
    YARD.parse_string(<<-RUBY)
      class A
        # @return [nil]
        attr_accessor :x
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        sig { returns(T.untyped) }
        attr_accessor :x
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class A
        attr_accessor x: untyped
      end
    RUBY
  end

  it 'works around the YARD "duplicated character after negative argument" bug' do
    YARD.parse_string(<<-RUBY)
      class A
        def x(a, b, c = -1, d = -2); end
        def y(a, b, c = -Something.complex(2, 3), d = -Something::ELSE); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "b", using untyped
        # sord omit - no YARD type given for "c", using untyped
        # sord omit - no YARD type given for "d", using untyped
        # sord omit - no YARD return type given, using untyped
        sig do
          params(
            a: T.untyped,
            b: T.untyped,
            c: T.untyped,
            d: T.untyped
          ).returns(T.untyped)
        end
        def x(a, b, c = -1, d = -2); end

        # sord omit - no YARD type given for "a", using untyped
        # sord omit - no YARD type given for "b", using untyped
        # sord omit - no YARD type given for "c", using untyped
        # sord omit - no YARD type given for "d", using untyped
        # sord omit - no YARD return type given, using untyped
        sig do
          params(
            a: T.untyped,
            b: T.untyped,
            c: T.untyped,
            d: T.untyped
          ).returns(T.untyped)
        end
        def y(a, b, c = -Something.complex(2, 3), d = -Something::ELSE); end
      end
    RUBY
  end

  it 'handles namespacing from root' do
    YARD.parse_string(<<-RUBY)
      class X
      end

      class Y
        class X
        end
      end

      class Z
        # @return [Y::X]
        def y_x; end

        # @return [::X]
        def x; end

        # @return [X]
        def ambiguous_x; end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class X
      end

      class Y
        class X
        end
      end

      class Z
        sig { returns(Y::X) }
        def y_x; end

        sig { returns(::X) }
        def x; end

        sig { returns(X) }
        def ambiguous_x; end
      end
    RUBY
  end

  it 'works with inline block as param' do
    YARD.parse_string(<<-RUBY)
      class A
        def x(a: -> () {}); end
        def y(a: ->() {}); end
        def z(a: -> {}); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # sord omit - no YARD type given for "a:", using untyped
        # sord omit - no YARD return type given, using untyped
        sig { params(a: T.untyped).returns(T.untyped) }
        def x(a: -> () {}); end

        # sord omit - no YARD type given for "a:", using untyped
        # sord omit - no YARD return type given, using untyped
        sig { params(a: T.untyped).returns(T.untyped) }
        def y(a: ->() {}); end

        # sord omit - no YARD type given for "a:", using untyped
        # sord omit - no YARD return type given, using untyped
        sig { params(a: T.untyped).returns(T.untyped) }
        def z(a: -> {}); end
      end
    RUBY
  end

  it 'works with YARD\'s overload tag' do
    YARD.parse_string(<<-RUBY)
      class A
        # @overload x(a, b)
        #   @param a [String]
        #   @param b [Integer]
        #   @return [void]
        def x(*args); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # _@param_ `a`
        # 
        # _@param_ `b`
        sig { params(a: String, b: Integer).void }
        def x(a, b); end
      end
    RUBY
  end

  it 'works with YARD\'s overload tag with toplevel return tag' do
    YARD.parse_string(<<-RUBY)
      class A
        # Comment for method x
        # @overload x(a, b)
        #   Overload comment
        #   @param a [String]
        #   @param b [Integer]
        # @return [Integer] example integer
        def x(*args); end
      end
    RUBY

    expect(rbi_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      # typed: strong
      class A
        # Comment for method x
        # Overload comment
        # 
        # _@param_ `a`
        # 
        # _@param_ `b`
        # 
        # _@return_ — example integer
        sig { params(a: String, b: Integer).returns(Integer) }
        def x(a, b); end
      end
    RUBY
  end

  it 'works even if the parent class has the same name' do
    YARD.parse_string(<<-RUBY)
      class X
      end

      module M
        class X < ::X
        end
      end
    RUBY

    expect(rbs_gen.generate.strip).to eq fix_heredoc(<<-RUBY)
      class X
      end

      module M
        class X < ::X
        end
      end
    RUBY
  end
end
