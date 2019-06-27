require 'yard'

describe Sord::RbiGenerator do
  before do
    YARD::Registry.clear
    Sord::Logging.silent = true
  end

  subject do
    # Create an unnamed class to emulate everything required in "options"
    Sord::RbiGenerator.new(Class.new do
      def comments; true; end
      def break_params; 4; end
    end.new)
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
    YARD.parse_string(<<-EOF)
      module A
        module B; end
        module C
          module D; end
        end
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      module A
        module B
        end

        module C
          module D
          end
        end
      end
    EOF
  end

  it 'handles structures with modules, classes and methods' do
    YARD.parse_string(<<-EOF)
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
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      module A
        class B
          sig { returns(Integer) }
          def foo(); end
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
      EOF
  end
  
  it 'auto-generates T.untyped signatures when unspecified and warns' do
    YARD.parse_string(<<-EOF)
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
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      module A
        class B
          # sord omit - no YARD return type given, using T.untyped
          sig { returns(T.untyped) }
          def foo(); end
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
      EOF
  end

  it 'generates inheritance, inclusion and extension' do
    YARD.parse_string(<<-EOF)
      class A; end
      class B; end
      class C; end

      class D < A
        extend B
        include C
        def x; end
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
        extend B
        include C

        # sord omit - no YARD return type given, using T.untyped
        sig { returns(T.untyped) }
        def x(); end
      end
    EOF
  end

  it 'generates blocks correctly' do
    YARD.parse_string(<<-EOF)
      module A
        # @param [String] x
        # @return [Boolean]
        # @yieldparam [Integer] a
        # @yieldparam [Float] b
        # @yieldreturn [Boolean] c
        def foo(x, &blk); end
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      module A
        sig { params(x: String, blk: T.proc.params(a: Integer, b: Float).returns(T::Boolean)).returns(T::Boolean) }
        def foo(x, &blk); end
      end
    EOF
  end

  it 'generates varargs correctly' do
    YARD.parse_string(<<-EOF)
      module A
        # @param [Integer] x
        # @param [Array<String>] y
        # @return [void]
        def foo(x, *y); end
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      module A
        sig { params(x: Integer, y: T::Array[String]).void }
        def foo(x, *y); end
      end
    EOF
  end

  it 'breaks parameters across multiple lines correctly' do
    YARD.parse_string(<<-EOF)
      module A
        # @param [Integer] a
        # @param [String] b
        # @param [Float] c
        # @param [Object] d
        # @return [void]
        def foo(a, b, c, d); end
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
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
    EOF
  end

  it 'infers setter types' do
    YARD.parse_string(<<-EOF)
      module A
        # @return [Integer]
        def x; end

        def x=(value); end
      end
    EOF

    expect(subject.generate.strip).to eq fix_heredoc(<<-EOF)
      # typed: strong
      module A
        sig { returns(Integer) }
        def x(); end

        # sord infer - inferred type of parameter "value" as Integer using getter's return type
        # sord omit - no YARD return type given, using T.untyped
        sig { params(value: Integer).returns(T.untyped) }
        def x=(value); end
      end
    EOF
  end
end