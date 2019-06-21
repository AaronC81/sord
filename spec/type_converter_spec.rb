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
        expect {
          expect(subject.yard_to_sorbet('String')).to eq 'String'
          expect(subject.yard_to_sorbet('::Kernel::Array')).to eq '::Kernel::Array'
        }.not_to log
      end

      it 'returns it with a warning if it looks like a non-namespace' do
        expect {
          expect(subject.yard_to_sorbet('foo')).to eq 'foo'
        }.to log :warn
      end

      it 'returns a replacement constant with a warning if it is not an identifier' do
        expect {
          expect(subject.yard_to_sorbet(':foo')).to eq 'SORD_ERROR_foo'
        }.to log :warn

        expect {
          expect(subject.yard_to_sorbet(':=^*abc&"(@')).to eq 'SORD_ERROR_abc'
        }.to log :warn
      end

      it 'can handle empty strings' do
        expect {
          expect(subject.yard_to_sorbet('')).to eq 'SORD_ERROR_'
        }.to log :warn
      end

      it 'coerces booleans' do
        expect {
          expect(subject.yard_to_sorbet('bool')).to eq 'T::Boolean'
          expect(subject.yard_to_sorbet('Boolean')).to eq 'T::Boolean'
        }.not_to log
      end

      context 'with type parameters' do
        it 'handles correctly-formed one-argument type parameters' do
          expect {
            expect(subject.yard_to_sorbet('Array<String>')).to eq 'T::Array[String]'
            expect(subject.yard_to_sorbet('Set<String>')).to eq 'T::Set[String]'
          }.not_to log
        end

        it 'returns a replacement constant with a warning if it is not a known generic' do
          expect {
            expect(subject.yard_to_sorbet('Foo<String>')).to eq 'SORD_ERROR_Foo'
          }.to log :warn
        end
      end
    end
  end
end