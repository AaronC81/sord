# Sord

## Overview

Sord is a **So**rbet and YA**RD** crossover. It can automatically generate
Sorbet type signatures files by looking at the types specified in YARD 
documentation comments.

If your project is already YARD documented, then this can generate most of the
Sorbet signatures you need!

Sord has the following features:
  - Automatically generates signatures for modules, classes and methods
  - Support for multiple parameter or return types (`T.any`)
  - Gracefully handles missing YARD types (`T.untyped`)
  - Can infer setter parameter type from the corresponding getter's return type
  - Recognises mixins (`include` and `extend`)
  - Support for generic types such as `Array<T>` and `Hash<K, V>`

## Usage

Install Sord with `gem install sord`.

Sord is a command line tool. To use it, open a terminal in the root directory
of your project, and run `yard` to generate a YARD registry if you haven't
already. Then, invoke `sord`, passing a path of where you'd like to save your
RBI to (this file will be overwritten):

```
sord defs.rbi
```

Sord will print information about what it's inferred as it runs. It is best to
fix any issues in the YARD documentation, as any edits made to the resulting
RBI file will be replaced if you re-run Sord.

## Example

Say we have this file, called `test.rb`:

```ruby
module Example
  class Person
    # @param [String] name
    # @param [Integer] age
    # @return [Example::Person]
    def initialize(name, age)
      @name = name
      @age = age
    end

    # @return [String] name
    attr_accessor :name

    # @return [Integer] age
    attr_accessor :age

    # @param [Array<String>] possible_names
    # @param [Array<Integer>] possible_ages
    # @return [Example::Person]
    def self.construct_randomly(possible_names, possible_ages)
      Person.new(possible_names.sample, possible_ages.sample)
    end
  end
end
```

First, generate a YARD registry by running `yardoc test.rb`. Then, we can run
`sord test.rbi` to generate the RBI file. (Careful not to overwrite your code
files! Note the `.rbi` file extension.) In doing this, Sord prints:

```
[INFER] (Example::Person#name=) inferred type of parameter "value" as String using getter's return type
[INFER] (Example::Person#age=) inferred type of parameter "value" as Integer using getter's return type
[DONE ] Processed 8 objects
```

The `test.rbi` file then contains a complete RBI file for `test.rb`:

```ruby
# typed: true
module Example
end
class Example::Person 
  sig { params(name: String, age: Integer).returns(Example::Person) }
  def initialize(name, age) end
  sig { params().returns(String) }
  def name() end
  # sord infer - inferred type of parameter "value" as String using getter's return type
  sig { params(value: String).returns(String) }
  def name=(value) end
  sig { params().returns(Integer) }
  def age() end
  # sord infer - inferred type of parameter "value" as Integer using getter's return type
  sig { params(value: Integer).returns(Integer) }
  def age=(value) end
  sig { params(possible_names: T::Array[String], possible_ages: T::Array[Integer]).returns(Example::Person) }
  def self.construct_randomly(possible_names, possible_ages) end
end
```

## Things to work on

  - I'm not 100% sure how this handles undocumented methods and classes.
  - More inference systems would be nice.
  - This won't generate type parameter definitions for things which mix-in
    `Enumerable`.
  - Module scoping is an issue - if `Example::Person` is replaced with `Person`
    in the YARD comments in the above example, Sorbet won't be able to resolve
    it. _This can be solved by making definitions syntactically heirarchical._
  - Tests!!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/AaronC81/sord. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sord project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/AaronC81/sord/blob/master/CODE_OF_CONDUCT.md).
