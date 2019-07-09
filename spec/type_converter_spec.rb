# typed: ignore
describe Sord::TypeConverter do
  before do
    Sord::Logging.silent = true
  end

  describe '#yard_to_sorbet' do
    context 'when given nil' do
      it 'assigns T.untyped to missing types' do
        expect(subject.yard_to_sorbet(nil)).to eq 'T.untyped'
      end
    end

    context 'when given an Array' do
      it 'unwraps it if it contains one item' do
        expect(subject.yard_to_sorbet(['String'])).to eq 'String'
      end

      it 'forms a T.any if it contains more than one item' do
        expect(subject.yard_to_sorbet(['String', 'Integer'])).to eq 'T.any(String, Integer)'
      end
    end

    context 'when given a String' do
      it 'returns it without logs if it is simple and a namespace/class' do
        expect(subject.yard_to_sorbet('String')).to eq 'String'
        expect(subject.yard_to_sorbet('::Kernel::Array')).to eq '::Kernel::Array'
      end

      it 'returns it with a warning if it looks like a non-namespace' do
        expect {
          expect(subject.yard_to_sorbet('foo')).to eq 'foo'
        }.to log :warn
      end

      it 'can handle empty strings' do
        expect {
          expect(subject.yard_to_sorbet('')).to eq 'SORD_ERROR_'
        }.to log :warn
      end

      it 'coerces \'boolean\' and its variants' do
        expect(subject.yard_to_sorbet('bool')).to eq 'T::Boolean'
        expect(subject.yard_to_sorbet('Boolean')).to eq 'T::Boolean'
      end

      it 'coerces boolean literals' do
        expect(subject.yard_to_sorbet('true')).to eq 'T::Boolean'
        expect(subject.yard_to_sorbet('false')).to eq 'T::Boolean'
        expect(subject.yard_to_sorbet(['true', 'false'])).to eq \
          'T::Boolean'
      end

      it 'converts types with nil to nilable' do
        expect(subject.yard_to_sorbet(['String', 'Integer', 'nil'])).to eq \
          'T.nilable(T.any(String, Integer))'
        expect(subject.yard_to_sorbet(['String', 'nil'])).to eq \
          'T.nilable(String)'
      end

      it 'converts literals to their types' do
        expect(subject.yard_to_sorbet([':up', ':down'])).to eq 'Symbol'
        expect(subject.yard_to_sorbet(['String', ':up', ':down'])).to eq \
          'T.any(String, Symbol)'
        expect(subject.yard_to_sorbet('3')).to eq 'Integer'
        expect(subject.yard_to_sorbet('3.14')).to eq 'Float'
        # expect(subject.yard_to_sorbet('\'foo\'')).to eq 'String'
      end

      it 'converts duck types to T.untyped' do
        expect(subject.yard_to_sorbet('#to_s')).to eq 'T.untyped'
        expect(subject.yard_to_sorbet('#setter=')).to eq 'T.untyped'
        expect(subject.yard_to_sorbet('#foo & #bar')).to eq 'T.untyped'
        expect(subject.yard_to_sorbet('#foo & #foo_bar & #baz')).to eq 'T.untyped'
        expect(subject.yard_to_sorbet('#foo&#bar')).to eq 'T.untyped'
        expect(subject.yard_to_sorbet('#foo & #setter=')).to eq 'T.untyped'
      end

      it 'does not convert invalid duck types' do
        expect(subject.yard_to_sorbet('#foo&bar')).to eq 'SORD_ERROR_foobar'
      end

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

        expect(subject.yard_to_sorbet('self', stub_method)).to eq 'Foo::Bar'
      end

      context 'with type parameters' do
        it 'handles correctly-formed one-argument type parameters' do
          expect(subject.yard_to_sorbet('Array<String>')).to eq 'T::Array[String]'
          expect(subject.yard_to_sorbet('Set<String>')).to eq 'T::Set[String]'
        end

        it 'uses T.any if multiple arguments are specified to a one-argument type parameter' do
          expect(subject.yard_to_sorbet('Array<String, Integer>')).to eq 'T::Array[T.any(String, Integer)]'
        end

        it 'handles whitespace' do
          expect(subject.yard_to_sorbet('Array < String >')).to eq 'T::Array[String]'
        end

        it 'handles correctly-formed two-argument type parameters' do
          expect(subject.yard_to_sorbet('Hash<String, Integer>')).to eq 'T::Hash[String, Integer]'
          expect(subject.yard_to_sorbet('Hash<Hash<String, Symbol>, Hash<Array<Symbol>, Integer>>')).to eq \
            'T::Hash[T::Hash[String, Symbol], T::Hash[T::Array[Symbol], Integer]]'
        end
        
        it 'handles correctly-formed two-argument type parameters with hash rockets' do
          expect(subject.yard_to_sorbet('Hash<String=>Symbol>')).to eq 'T::Hash[String, Symbol]'
          expect(subject.yard_to_sorbet('Hash{String=>Symbol}')).to eq 'T::Hash[String, Symbol]'
          expect(subject.yard_to_sorbet('Hash{String => Symbol}')).to eq 'T::Hash[String, Symbol]'
          expect(subject.yard_to_sorbet('Hash<Hash{String => Symbol}, Hash<Array<Symbol>, Integer>>')).to eq \
            'T::Hash[T::Hash[String, Symbol], T::Hash[T::Array[Symbol], Integer]]'
          expect(subject.yard_to_sorbet('Hash{Hash{String => Symbol} => Hash{Array<Symbol> => Integer}}')).to eq \
            'T::Hash[T::Hash[String, Symbol], T::Hash[T::Array[Symbol], Integer]]'
        end

        it 'returns a replacement constant with a warning if it is not a known generic' do
          expect {
            expect(subject.yard_to_sorbet('Foo<String>')).to eq 'SORD_ERROR_Foo'
          }.to log :warn
        end

        it 'handles order-dependent lists by returning Tuples' do
          expect(subject.yard_to_sorbet('Array(String, Integer)')).to eq '[String, Integer]'
          expect(subject.yard_to_sorbet('Array(Integer, Integer)')).to eq '[Integer, Integer]'
          expect(subject.yard_to_sorbet('Array(Fixnum, String, Symbol, Integer)')).to eq '[Fixnum, String, Symbol, Integer]'
          expect(subject.yard_to_sorbet('(String, Integer)')).to eq '[String, Integer]'
        end

        it 'handles nested order-dependent lists by returning nested Tuples' do
          expect(subject.yard_to_sorbet('(String, Symbol, Array(String, Symbol))')).to eq '[String, Symbol, [String, Symbol]]'
          expect(subject.yard_to_sorbet('(String, Symbol, (String, Symbol))')).to eq '[String, Symbol, [String, Symbol]]'
        end

        it 'handles shorthand Hash syntax' do
          expect(subject.yard_to_sorbet('{String => Symbol}')).to eq 'T::Hash[String, Symbol]'
          expect(subject.yard_to_sorbet('{{String => Integer} => {Symbol => Float}}')).to eq 'T::Hash[T::Hash[String, Integer], T::Hash[Symbol, Float]]'
        end

        it 'handles shorthand Array syntax' do
          expect(subject.yard_to_sorbet('<String>')).to eq 'T::Array[String]'
          expect(subject.yard_to_sorbet('<String, <Boolean, Symbol>>')).to eq 'T::Array[T.any(String, T::Array[T.any(T::Boolean, Symbol)])]'
        end

        it 'converts Class types' do
          expect(subject.yard_to_sorbet('Class<String>')).to eq 'T.class_of(String)'
        end
      end

      context 'invalid YARD docs' do
        it 'SORD_ERROR for invalid duck types' do
          expect(subject.yard_to_sorbet('foo&bar')).to eq 'SORD_ERROR_foobar'
          expect(subject.yard_to_sorbet('foo&#bar')).to eq 'SORD_ERROR_foobar'
          expect(subject.yard_to_sorbet('#foo&bar')).to eq 'SORD_ERROR_foobar'
          expect(subject.yard_to_sorbet('#foo-bar')).to eq 'SORD_ERROR_foobar'
          expect(subject.yard_to_sorbet('#=foobar')).to eq 'SORD_ERROR_foobar'
        end

        it 'SORD_ERROR for invalid hashes with uneven curly braces' do
          expect(subject.yard_to_sorbet('Hash{String, Symbol')).to eq 'SORD_ERROR_HashStringSymbol'
          expect(subject.yard_to_sorbet('Hash{String')).to eq 'SORD_ERROR_HashString'
        end
        
        it 'SORD_ERROR for invalid Arrays with uneven angle brackets' do
          expect(subject.yard_to_sorbet('Array<String, Symbol')).to eq 'SORD_ERROR_ArrayStringSymbol'
          expect(subject.yard_to_sorbet('Array<String')).to eq 'SORD_ERROR_ArrayString'
        end
        
        it 'SORD_ERROR for a type list not inside a container' do
          expect(subject.yard_to_sorbet('String, Symbol')).to eq 'SORD_ERROR_StringSymbol'
        end

        it 'T.untyped rather than SORD_ERROR if option is set' do
          expect(subject.yard_to_sorbet('Hash{String, Symbol', nil, true)).to eq 'T.untyped'
        end

        it 'T.untyped rather than unresolved constant if option is set' do
          expect(subject.yard_to_sorbet('TestConstantThatDoesNotExist', YARD::CodeObjects::NamespaceObject.new(:root, :Foo), false, true)).to eq 'T.untyped'
        end
      end
    end
  end
end
