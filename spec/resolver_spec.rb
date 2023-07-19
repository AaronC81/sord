# typed: ignore
require 'yard'

describe Sord::Resolver do
  before do
    YARD::Registry.clear
    Sord::Logging.silent = true
    Sord::Resolver.clear
  end

  def at(name)
    YARD::Registry.at(name)
  end

  it 'returns a sensible list of built-in classes' do
    expect(subject.builtin_classes).to include 'String', 'Numeric', 'Integer', 'Float', 'IO'
  end

  it 'resolves built-in classes without ambiguity' do
    YARD.parse_string(<<-RUBY)
      class A
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('String', at('A'))).to be true
  end

  it 'does not resolve built-in classes with ambiguity' do
    YARD.parse_string(<<-RUBY)
      module A
        class String
        end

        class B
        end
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('String', at('A::B'))).to be false
    expect(subject.path_for('String')).to be nil
  end

  it 'resolves parent modules' do
    YARD.parse_string(<<-RUBY)
      module A
        module B
          module C
            class D
            end
          end
        end
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('B', at('A::B::C::D'))).to be true
  end

  it 'resolves siblings of parent modules' do
    YARD.parse_string(<<-RUBY)
      module A
        module B
          module C
            class D
            end
          end
        end

        class E
        end
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('E', at('A::B::C::D'))).to be true
  end

  it 'can infer unresolvable module structures without ambiguity' do
    YARD.parse_string(<<-RUBY)
      module A
        module B
          module C
            class D
            end
          end
        end

        module E
          class F
          end
        end
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('F', at('A::B::C::D'))).to be false
    expect(subject.path_for('F')).to eq 'A::E::F'
  end

  it 'does not resolve ambiguity' do
    YARD.parse_string(<<-RUBY)
      module A
        module B
          module C
            class D
            end
          end
        end

        module E
          class F
          end
        end

        module G
          class F
          end
        end
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('F', at('A::B::C::D'))).to be false
    expect(subject.path_for('F')).to be nil
  end

  it 'resolves the most nested module in a conflict of resolvable modules' do
    YARD.parse_string(<<-RUBY)
      module A
        module B
          class A
            class D
            end
          end
        end
      end
    RUBY

    subject.prepare
    expect(subject.resolvable?('A', at('A::B::A::D'))).to be true
  end

  it 'can resolve from the root namespace' do
    YARD.parse_string(<<-RUBY)
      module A
        class B
        end
      end

      class B
      end
    RUBY

    subject.prepare

    expect(subject.path_for('A::B')).to eq 'A::B'
    expect(subject.path_for('::B')).to eq '::B'

    expect(subject.path_for('B')).to be nil # Ambiguous
  end

end
