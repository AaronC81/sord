# typed: ignore
describe Sord::TypeConverter do
  Types = Parlour::Types

  before do
    Sord::Logging.silent = true
  end

  describe '#yard_to_parlour' do
    def default_config
      Sord::TypeConverter::Configuration.new(
        output_language: :rbi,
        replace_errors_with_untyped: false,
        replace_unresolved_with_untyped: false,
      )
    end

    def yard_to_parlour_default(type)
      subject.yard_to_parlour(type, nil, default_config)
    end

    context 'when given nil' do
      it 'assigns untyped to missing types' do
        expect(yard_to_parlour_default(nil)).to eq Types::Untyped.new
      end
    end

    context 'with String' do
      it 'returns it without logs if it is simple and a namespace/class' do
        expect(yard_to_parlour_default('String')).to eq Types::Raw.new('String')
        expect(yard_to_parlour_default('::Kernel::Array')).to eq Types::Raw.new('::Kernel::Array')
      end

      it 'returns it with a warning if it looks like a non-namespace' do
        expect {
          expect(yard_to_parlour_default('foo')).to eq Types::Raw.new('foo')
        }.to log :warn
      end

      it 'can handle empty strings' do
        expect {
          expect(yard_to_parlour_default('')).to eq Types::Raw.new('SORD_ERROR_')
        }.to log :warn
      end
    end

    context 'with Boolean' do
      it 'coerces \'boolean\' and its variants' do
        expect(yard_to_parlour_default('bool')).to eq Types::Boolean.new
        expect(yard_to_parlour_default('Boolean')).to eq Types::Boolean.new
      end

      it 'coerces boolean literals' do
        expect(yard_to_parlour_default('true')).to eq Types::Boolean.new
        expect(yard_to_parlour_default('false')).to eq Types::Boolean.new
        expect(yard_to_parlour_default(['true', 'false'])).to eq \
          Types::Boolean.new
      end
    end

    context 'with undefined' do
      it 'translates to untyped' do
        expect(yard_to_parlour_default('undefined')).to eq Types::Untyped.new
      end
    end

    context 'with multiple types' do
      it 'unwraps it if it contains one item' do
        expect(yard_to_parlour_default(['String'])).to eq Types::Raw.new('String')
      end

      it 'forms a T.any if it contains more than one item' do
        expect(yard_to_parlour_default(['String', 'Integer'])).to eq Types::Union.new(['String', 'Integer'])
      end

      it 'converts types with nil to nilable' do
        expect(yard_to_parlour_default(['String', 'Integer', 'nil'])).to eq \
          Types::Nilable.new(Types::Union.new(['String', 'Integer']))
        expect(yard_to_parlour_default(['String', 'nil'])).to eq \
          Types::Nilable.new('String')
      end
    end

    context 'with literals' do
      it 'converts literals to their types' do
        expect(yard_to_parlour_default([':up', ':down'])).to eq Types::Raw.new('Symbol')
        expect(yard_to_parlour_default(['String', ':up', ':down'])).to eq \
          Types::Union.new(['String', 'Symbol'])
        expect(yard_to_parlour_default('3')).to eq Types::Raw.new('Integer')
        expect(yard_to_parlour_default('3.14')).to eq Types::Raw.new('Float')
        # expect(yard_to_parlour_default('\'foo\'')).to eq 'String'
      end
    end

    context 'with duck types' do
      it 'converts duck types to T.untyped' do
        expect(yard_to_parlour_default('#to_s')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#setter=')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#foo & #bar')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#foo & #foo_bar & #baz')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#foo&#bar')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#foo & #setter=')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#foo!')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#===')).to eq Types::Untyped.new
        expect(yard_to_parlour_default('#=== & #[]= & #!~')).to eq Types::Untyped.new
      end

      it 'does not convert invalid duck types' do
        expect(yard_to_parlour_default('#foo&bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
      end
    end

    context 'with self' do
      it 'supports self' do
        # Create a stub object which partially behaves like a CodeObject method
        stub_method = Module.new do
          def self.parent
            Module.new do
              def self.path
                "Foo::Bar"
              end
            end
          end
        end

        expect(subject.yard_to_parlour('self', stub_method, default_config)).to eq Types::Self.new
      end
    end

    context 'with type parameters' do
      it 'handles correctly-formed one-argument type parameters' do
        expect(yard_to_parlour_default('Array<String>')).to eq Types::Array.new('String')
        expect(yard_to_parlour_default('Set<String>')).to eq Types::Set.new('String')
      end

      it 'uses T.any if multiple arguments are specified to a one-argument type parameter' do
        expect(yard_to_parlour_default('Array<String, Integer>')).to eq \
          Types::Array.new(Types::Union.new(['String', 'Integer']))
      end

      it 'handles whitespace' do
        expect(yard_to_parlour_default('Array < String >')).to eq Types::Array.new('String')
      end

      it 'handles correctly-formed two-argument type parameters' do
        expect(yard_to_parlour_default('Hash<String, Integer>')).to eq Types::Hash.new('String', 'Integer')
        expect(yard_to_parlour_default('Hash<Hash<String, Symbol>, Hash<Array<Symbol>, Integer>>')).to eq \
          Types::Hash.new(
            Types::Hash.new('String', 'Symbol'),
            Types::Hash.new(Types::Array.new('Symbol'), 'Integer')
          )
      end

      it 'handles correctly-formed two-argument type parameters with hash rockets' do
        expect(yard_to_parlour_default('Hash<String=>Symbol>')).to eq Types::Hash.new('String', 'Symbol')
        expect(yard_to_parlour_default('Hash{String=>Symbol}')).to eq Types::Hash.new('String', 'Symbol')
        expect(yard_to_parlour_default('Hash{String => Symbol}')).to eq Types::Hash.new('String', 'Symbol')
        expect(yard_to_parlour_default('Hash{String, Integer => Symbol, Float}')).to eq \
          Types::Hash.new(
            Types::Union.new(['String', 'Integer']),
            Types::Union.new(['Symbol', 'Float'])
        )
        expect(yard_to_parlour_default('Hash<Hash{String => Symbol}, Hash<Array<Symbol>, Integer>>')).to eq \
          Types::Hash.new(
            Types::Hash.new('String', 'Symbol'),
            Types::Hash.new(Types::Array.new('Symbol'), 'Integer')
          )
        expect(yard_to_parlour_default('Hash{Hash{String => Symbol} => Hash{Array<Symbol> => Integer}}')).to eq \
          Types::Hash.new(
            Types::Hash.new('String', 'Symbol'),
            Types::Hash.new(Types::Array.new('Symbol'), 'Integer')
          )
      end

      it 'handles order-dependent lists by returning Tuples' do
        expect(yard_to_parlour_default('Array(String, Integer)')).to eq Types::Tuple.new(['String', 'Integer'])
        expect(yard_to_parlour_default('Array(Integer, Integer)')).to eq Types::Tuple.new(['Integer', 'Integer'])
        expect(yard_to_parlour_default('Array(Fixnum, String, Symbol, Integer)')).to eq \
          Types::Tuple.new(['Fixnum', 'String', 'Symbol', 'Integer'])
        expect(yard_to_parlour_default('(String, Integer)')).to eq \
          Types::Tuple.new(['String', 'Integer'])
      end

      it 'handles nested order-dependent lists by returning nested Tuples' do
        expect(yard_to_parlour_default('(String, Symbol, Array(String, Symbol))')).to eq \
          Types::Tuple.new(['String', 'Symbol', Types::Tuple.new(['String', 'Symbol'])])
        expect(yard_to_parlour_default('(String, Symbol, (String, Symbol))')).to eq \
          Types::Tuple.new(['String', 'Symbol', Types::Tuple.new(['String', 'Symbol'])])
      end

      it 'handles shorthand Hash syntax' do
        expect(yard_to_parlour_default('{String => Symbol}')).to eq Types::Hash.new('String', 'Symbol')
        expect(yard_to_parlour_default('{{String => Integer} => {Symbol => Float}}')).to eq \
          Types::Hash.new(Types::Hash.new('String', 'Integer'), Types::Hash.new('Symbol', 'Float'))
        expect(yard_to_parlour_default('{{String, Integer}, {Symbol, Float}}')).to eq \
          Types::Hash.new(Types::Hash.new('String', 'Integer'), Types::Hash.new('Symbol', 'Float'))
      end

      it 'handles shorthand Array syntax' do
        expect(yard_to_parlour_default('<String>')).to eq Types::Array.new('String')
        expect(yard_to_parlour_default('<String, <Boolean, Symbol>>')).to eq \
          Types::Array.new(
            Types::Union.new([
              'String', Types::Array.new(
                Types::Union.new([Types::Boolean.new, 'Symbol'])
              )
            ])
          )
      end

      it 'converts Class types' do
        expect(yard_to_parlour_default('Class<String>')).to eq Types::Class.new('String')
      end

      it 'converts Class types with multiple parameters' do
        expect(yard_to_parlour_default('Class<String, Integer>')).to eq \
          Types::Union.new([
            Types::Class.new('String'),
            Types::Class.new('Integer'),
          ])
      end

      context 'with user defined generic' do
        it 'handles single parameter' do
          expect(yard_to_parlour_default('Wrapper<String>')).to eq \
            Types::Generic.new(
              Types::Raw.new('Wrapper'),
              [Types::Raw.new('String')]
          )
        end

        it 'handles multiple parameter' do
          expect(yard_to_parlour_default('Mapper<String, Integer>')).to eq \
            Types::Generic.new(
              Types::Raw.new('Mapper'),
              [Types::Raw.new('String'), Types::Raw.new('Integer')]
          )
        end

        it 'handles nested parameters' do
          expect(yard_to_parlour_default('Wrapper<Wrapper<String>>')).to eq \
            Types::Generic.new(
              Types::Raw.new('Wrapper'),
              [
                Types::Generic.new(
                  Types::Raw.new('Wrapper'),
                  [Types::Raw.new('String')]
                )
              ]
          )
        end
      end

      it 'does not resolve stdlib objects instead of types when using the root namespace' do
        expect(yard_to_parlour_default('::Array<String>')).to eq Types::Array.new('String')
      end
    end

    context 'when given an untyped generic' do
      it 'handles Hash correctly' do
        expect(yard_to_parlour_default('Hash')).to eq Types::Hash.new(Types::Untyped.new, Types::Untyped.new)
      end

      it 'handles Array correctly' do
        expect(yard_to_parlour_default('Array')).to eq Types::Array.new(Types::Untyped.new)
      end

      it 'handles Range correctly' do
        expect(yard_to_parlour_default('Range')).to eq Types::Range.new(Types::Untyped.new)
      end

      it 'handles Set correctly' do
        expect(yard_to_parlour_default('Set')).to eq Types::Set.new(Types::Untyped.new)
      end

      it 'handles Enumerable correctly' do
        expect(yard_to_parlour_default('Enumerable')).to eq Types::Enumerable.new(Types::Untyped.new)
      end

      it 'handles Enumerator correctly' do
        expect(yard_to_parlour_default('Enumerator')).to eq Types::Enumerator.new(Types::Untyped.new)
      end
    end

    context 'invalid YARD docs' do
      it 'SORD_ERROR for invalid duck types' do
        expect(yard_to_parlour_default('foo&bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(yard_to_parlour_default('foo&#bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(yard_to_parlour_default('#foo&bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(yard_to_parlour_default('#foo-bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(yard_to_parlour_default('#=foobar')).to eq Types::Raw.new('SORD_ERROR_foobar')
      end

      it 'SORD_ERROR for invalid hashes with uneven curly braces' do
        expect(yard_to_parlour_default('Hash{String, Symbol')).to eq Types::Raw.new('SORD_ERROR_HashStringSymbol')
        expect(yard_to_parlour_default('Hash{String')).to eq Types::Raw.new('SORD_ERROR_HashString')
      end

      it 'SORD_ERROR for invalid Arrays with uneven angle brackets' do
        expect(yard_to_parlour_default('Array<String, Symbol')).to eq Types::Raw.new('SORD_ERROR_ArrayStringSymbol')
        expect(yard_to_parlour_default('Array<String')).to eq Types::Raw.new('SORD_ERROR_ArrayString')
      end

      it 'SORD_ERROR for a type list not inside a container' do
        expect(yard_to_parlour_default('String, Symbol')).to eq Types::Raw.new('SORD_ERROR_StringSymbol')
      end

      it 'T.untyped rather than SORD_ERROR if option is set' do
        expect(subject.yard_to_parlour(
          'Hash{String, Symbol', nil,
          Sord::TypeConverter::Configuration.new(
            output_language: :rbi,
            replace_errors_with_untyped: true,
            replace_unresolved_with_untyped: true,
          )
        )).to eq Types::Untyped.new
      end

      it 'T.untyped rather than unresolved constant if option is set' do
        expect(subject.yard_to_parlour(
          'TestConstantThatDoesNotExist', YARD::CodeObjects::NamespaceObject.new(:root, :Foo),
          Sord::TypeConverter::Configuration.new(
            output_language: :rbi,
            replace_errors_with_untyped: false,
            replace_unresolved_with_untyped: true,
          )
        )).to eq Types::Untyped.new
      end

      it 'SORD_ERROR for a hash with too many parameters' do
        expect(yard_to_parlour_default('{Integer, Integer, Integer}')).to eq Types::Raw.new('SORD_ERROR_IntegerIntegerInteger')
      end

      it 'SORD_ERROR for a hash with too few parameters' do
        expect(yard_to_parlour_default('{Integer}')).to eq Types::Raw.new('SORD_ERROR_Integer')
      end

      it 'SORD_ERROR for a hash with too few parameters' do
        expect(yard_to_parlour_default('Hash<Array>')).to eq Types::Raw.new('SORD_ERROR_Arrayuntyped')
      end
    end

    context 'when using RBS' do
      let :config do
        Sord::TypeConverter::Configuration.new(
          output_language: :rbs,
          replace_errors_with_untyped: false,
          replace_unresolved_with_untyped: false,
        )
      end

      it 'replaces known duck types with built-in interfaces' do
        # Converts known types
        expect(subject.yard_to_parlour('#to_s', nil, config)).to eq Types::Raw.new('_ToS')
        expect(subject.yard_to_parlour('#to_i', nil, config)).to eq Types::Raw.new('_ToI')
        expect(subject.yard_to_parlour('#write', nil, config)).to eq Types::Raw.new('_Writer')
        expect(subject.yard_to_parlour('#to_hash', nil, config)).to eq Types::Raw.new('_ToHash[untyped, untyped]')

        # Doesn't convert unknown types
        expect(subject.yard_to_parlour('#foobar', nil, config)).to eq Types::Untyped.new

        # Doesn't affect RBI, where these interfaces don't exist
        expect(yard_to_parlour_default('#to_s')).to eq Types::Untyped.new
      end
    end
  end
end
