# typed: ignore
describe Sord::TypeConverter do
  Types = Parlour::Types

  before do
    Sord::Logging.silent = true
  end

  describe '#yard_to_parlour' do
    context 'when given nil' do
      it 'assigns untyped to missing types' do
        expect(subject.yard_to_parlour(nil)).to eq Types::Untyped.new
      end
    end

    context 'with String' do
      it 'returns it without logs if it is simple and a namespace/class' do
        expect(subject.yard_to_parlour('String')).to eq Types::Raw.new('String')
        expect(subject.yard_to_parlour('::Kernel::Array')).to eq Types::Raw.new('::Kernel::Array')
      end

      it 'returns it with a warning if it looks like a non-namespace' do
        expect {
          expect(subject.yard_to_parlour('foo')).to eq Types::Raw.new('foo')
        }.to log :warn
      end

      it 'can handle empty strings' do
        expect {
          expect(subject.yard_to_parlour('')).to eq Types::Raw.new('SORD_ERROR_')
        }.to log :warn
      end
    end

    context 'with Boolean' do
      it 'coerces \'boolean\' and its variants' do
        expect(subject.yard_to_parlour('bool')).to eq Types::Boolean.new
        expect(subject.yard_to_parlour('Boolean')).to eq Types::Boolean.new
      end

      it 'coerces boolean literals' do
        expect(subject.yard_to_parlour('true')).to eq Types::Boolean.new
        expect(subject.yard_to_parlour('false')).to eq Types::Boolean.new
        expect(subject.yard_to_parlour(['true', 'false'])).to eq \
          Types::Boolean.new
      end
    end

    context 'with multiple types' do
      it 'unwraps it if it contains one item' do
        expect(subject.yard_to_parlour(['String'])).to eq Types::Raw.new('String')
      end

      it 'forms a T.any if it contains more than one item' do
        expect(subject.yard_to_parlour(['String', 'Integer'])).to eq Types::Union.new(['String', 'Integer'])
      end

      it 'converts types with nil to nilable' do
        expect(subject.yard_to_parlour(['String', 'Integer', 'nil'])).to eq \
          Types::Nilable.new(Types::Union.new(['String', 'Integer']))
        expect(subject.yard_to_parlour(['String', 'nil'])).to eq \
          Types::Nilable.new('String')
      end
    end

    context 'with literals' do
      it 'converts literals to their types' do
        expect(subject.yard_to_parlour([':up', ':down'])).to eq Types::Raw.new('Symbol')
        expect(subject.yard_to_parlour(['String', ':up', ':down'])).to eq \
          Types::Union.new(['String', 'Symbol'])
        expect(subject.yard_to_parlour('3')).to eq Types::Raw.new('Integer')
        expect(subject.yard_to_parlour('3.14')).to eq Types::Raw.new('Float')
        # expect(subject.yard_to_parlour('\'foo\'')).to eq 'String'
      end
    end

    context 'with duck types' do
      it 'converts duck types to T.untyped' do
        expect(subject.yard_to_parlour('#to_s')).to eq Types::Untyped.new
        expect(subject.yard_to_parlour('#setter=')).to eq Types::Untyped.new
        expect(subject.yard_to_parlour('#foo & #bar')).to eq Types::Untyped.new
        expect(subject.yard_to_parlour('#foo & #foo_bar & #baz')).to eq Types::Untyped.new
        expect(subject.yard_to_parlour('#foo&#bar')).to eq Types::Untyped.new
        expect(subject.yard_to_parlour('#foo & #setter=')).to eq Types::Untyped.new
      end

      it 'does not convert invalid duck types' do
        expect(subject.yard_to_parlour('#foo&bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
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

        expect(subject.yard_to_parlour('self', stub_method)).to eq Types::Self.new
      end
    end

    context 'with type parameters' do
      it 'handles correctly-formed one-argument type parameters' do
        expect(subject.yard_to_parlour('Array<String>')).to eq Types::Array.new('String')
        expect(subject.yard_to_parlour('Set<String>')).to eq Types::Set.new('String')
      end

      it 'uses T.any if multiple arguments are specified to a one-argument type parameter' do
        expect(subject.yard_to_parlour('Array<String, Integer>')).to eq \
          Types::Array.new(Types::Union.new(['String', 'Integer']))
      end

      it 'handles whitespace' do
        expect(subject.yard_to_parlour('Array < String >')).to eq Types::Array.new('String')
      end

      it 'handles correctly-formed two-argument type parameters' do
        expect(subject.yard_to_parlour('Hash<String, Integer>')).to eq Types::Hash.new('String', 'Integer')
        expect(subject.yard_to_parlour('Hash<Hash<String, Symbol>, Hash<Array<Symbol>, Integer>>')).to eq \
          Types::Hash.new(
            Types::Hash.new('String', 'Symbol'),
            Types::Hash.new(Types::Array.new('Symbol'), 'Integer')
          )
      end

      it 'handles correctly-formed two-argument type parameters with hash rockets' do
        expect(subject.yard_to_parlour('Hash<String=>Symbol>')).to eq Types::Hash.new('String', 'Symbol')
        expect(subject.yard_to_parlour('Hash{String=>Symbol}')).to eq Types::Hash.new('String', 'Symbol')
        expect(subject.yard_to_parlour('Hash{String => Symbol}')).to eq Types::Hash.new('String', 'Symbol')
        expect(subject.yard_to_parlour('Hash<Hash{String => Symbol}, Hash<Array<Symbol>, Integer>>')).to eq \
          Types::Hash.new(
            Types::Hash.new('String', 'Symbol'),
            Types::Hash.new(Types::Array.new('Symbol'), 'Integer')
          )
        expect(subject.yard_to_parlour('Hash{Hash{String => Symbol} => Hash{Array<Symbol> => Integer}}')).to eq \
          Types::Hash.new(
            Types::Hash.new('String', 'Symbol'),
            Types::Hash.new(Types::Array.new('Symbol'), 'Integer')
          )
      end

      it 'handles order-dependent lists by returning Tuples' do
        expect(subject.yard_to_parlour('Array(String, Integer)')).to eq Types::Tuple.new(['String', 'Integer'])
        expect(subject.yard_to_parlour('Array(Integer, Integer)')).to eq Types::Tuple.new(['Integer', 'Integer'])
        expect(subject.yard_to_parlour('Array(Fixnum, String, Symbol, Integer)')).to eq \
          Types::Tuple.new(['Fixnum', 'String', 'Symbol', 'Integer'])
        expect(subject.yard_to_parlour('(String, Integer)')).to eq \
          Types::Tuple.new(['String', 'Integer'])
      end

      it 'handles nested order-dependent lists by returning nested Tuples' do
        expect(subject.yard_to_parlour('(String, Symbol, Array(String, Symbol))')).to eq \
          Types::Tuple.new(['String', 'Symbol', Types::Tuple.new(['String', 'Symbol'])])
        expect(subject.yard_to_parlour('(String, Symbol, (String, Symbol))')).to eq \
          Types::Tuple.new(['String', 'Symbol', Types::Tuple.new(['String', 'Symbol'])])
      end

      it 'handles shorthand Hash syntax' do
        expect(subject.yard_to_parlour('{String => Symbol}')).to eq Types::Hash.new('String', 'Symbol')
        expect(subject.yard_to_parlour('{{String => Integer} => {Symbol => Float}}')).to eq \
          Types::Hash.new(Types::Hash.new('String', 'Integer'), Types::Hash.new('Symbol', 'Float'))
        expect(subject.yard_to_parlour('{{String, Integer}, {Symbol, Float}}')).to eq \
          Types::Hash.new(Types::Hash.new('String', 'Integer'), Types::Hash.new('Symbol', 'Float'))
      end

      it 'handles shorthand Array syntax' do
        expect(subject.yard_to_parlour('<String>')).to eq Types::Array.new('String')
        expect(subject.yard_to_parlour('<String, <Boolean, Symbol>>')).to eq \
          Types::Array.new(
            Types::Union.new([
              'String', Types::Array.new(
                Types::Union.new([Types::Boolean.new, 'Symbol'])
              )
            ])
          )
      end

      it 'converts Class types' do
        expect(subject.yard_to_parlour('Class<String>')).to eq Types::Class.new('String')
      end

      context 'with user defined generic' do
        it 'handles single parameter' do
          expect(subject.yard_to_parlour('Wrapper<String>')).to eq \
            Types::Generic.new(
              Types::Raw.new('Wrapper'),
              [Types::Raw.new('String')]
          )
        end

        it 'handles multiple parameter' do
          expect(subject.yard_to_parlour('Mapper<String, Integer>')).to eq \
            Types::Generic.new(
              Types::Raw.new('Mapper'),
              [Types::Raw.new('String'), Types::Raw.new('Integer')]
          )
        end

        it 'handles nested parameters' do
          expect(subject.yard_to_parlour('Wrapper<Wrapper<String>>')).to eq \
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
    end

    context 'when given an untyped generic' do
      it 'handles Hash correctly' do
        expect(subject.yard_to_parlour('Hash')).to eq Types::Hash.new(Types::Untyped.new, Types::Untyped.new)
      end

      it 'handles Array correctly' do
        expect(subject.yard_to_parlour('Array')).to eq Types::Array.new(Types::Untyped.new)
      end

      it 'handles Range correctly' do
        expect(subject.yard_to_parlour('Range')).to eq Types::Range.new(Types::Untyped.new)
      end

      it 'handles Set correctly' do
        expect(subject.yard_to_parlour('Set')).to eq Types::Set.new(Types::Untyped.new)
      end

      it 'handles Enumerable correctly' do
        expect(subject.yard_to_parlour('Enumerable')).to eq Types::Enumerable.new(Types::Untyped.new)
      end

      it 'handles Enumerator correctly' do
        expect(subject.yard_to_parlour('Enumerator')).to eq Types::Enumerator.new(Types::Untyped.new)
      end
    end

    context 'invalid YARD docs' do
      it 'SORD_ERROR for invalid duck types' do
        expect(subject.yard_to_parlour('foo&bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(subject.yard_to_parlour('foo&#bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(subject.yard_to_parlour('#foo&bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(subject.yard_to_parlour('#foo-bar')).to eq Types::Raw.new('SORD_ERROR_foobar')
        expect(subject.yard_to_parlour('#=foobar')).to eq Types::Raw.new('SORD_ERROR_foobar')
      end

      it 'SORD_ERROR for invalid hashes with uneven curly braces' do
        expect(subject.yard_to_parlour('Hash{String, Symbol')).to eq Types::Raw.new('SORD_ERROR_HashStringSymbol')
        expect(subject.yard_to_parlour('Hash{String')).to eq Types::Raw.new('SORD_ERROR_HashString')
      end

      it 'SORD_ERROR for invalid Arrays with uneven angle brackets' do
        expect(subject.yard_to_parlour('Array<String, Symbol')).to eq Types::Raw.new('SORD_ERROR_ArrayStringSymbol')
        expect(subject.yard_to_parlour('Array<String')).to eq Types::Raw.new('SORD_ERROR_ArrayString')
      end

      it 'SORD_ERROR for a type list not inside a container' do
        expect(subject.yard_to_parlour('String, Symbol')).to eq Types::Raw.new('SORD_ERROR_StringSymbol')
      end

      it 'T.untyped rather than SORD_ERROR if option is set' do
        expect(subject.yard_to_parlour('Hash{String, Symbol', nil, true)).to eq Types::Untyped.new
      end

      it 'T.untyped rather than unresolved constant if option is set' do
        expect(subject.yard_to_parlour('TestConstantThatDoesNotExist', YARD::CodeObjects::NamespaceObject.new(:root, :Foo), false, true)).to eq Types::Untyped.new
      end

      it 'SORD_ERROR for a hash with too many parameters' do
        expect(subject.yard_to_parlour('{Integer, Integer, Integer}')).to eq Types::Raw.new('SORD_ERROR_IntegerIntegerInteger')
      end

      it 'SORD_ERROR for a hash with too few parameters' do
        expect(subject.yard_to_parlour('{Integer}')).to eq Types::Raw.new('SORD_ERROR_Integer')
      end

      it 'SORD_ERROR for a hash with too few parameters' do
        expect(subject.yard_to_parlour('Hash<Array>')).to eq Types::Raw.new('SORD_ERROR_Arrayuntyped')
      end
    end
  end
end
