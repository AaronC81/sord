# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [7.1.0] - 2025-07-07
### Added
- `nil` can be used as an alias for `NilClass` in more places in YARD types. (Thanks @apiology)
- The Solargraph convention `undefined` can now be used as an "untyped" type. (Thanks @apiology)

### Changed
- If a constant's value does not parse successfully, type information can still be generated for
  that constant, and Sord emits a warning. Previously, this would cause a fatal exception.
- The version restriction on the RBS gem has been relaxed, to permit usage of 4.x versions.
  RBS 3.x can still be used as before.
  (Thanks @apiology)

### Fixed
- Sord now correctly resolves namespaces when classes have a namespace, e.g. `class X::Y`.
  (Thanks @dorner)

## [7.0.0] - 2025-03-03
### Added
- Messages now show the file and line number that the message originated from. (Thanks @apiology)
- Sord will now recognise `Class<T, E>` as an equivalent of `Class<T>, Class<E>`, similar to the
  existing behaviour for `Array`. (Thanks @tomoasleep)

### Changed
- **Breaking change**: Now uses Commander 5.0 to support Ruby 3.3. This increases the minimum
  required Ruby version to 3.0.
- **Breaking change**: Parlour version has been bumped significantly, from 5.0 to 9.1. This may be
  relevant if you're using other Parlour plugins alongside Sord.

### Fixed
- Sord now generates correct RBI when heredoc strings are used in constants. (Thanks @apiology)
- Fixed error when using as a Parlour plugin, but without any custom tags defined. (Thanks
  @dsisnero)
- Fixed incorrect precedence when union types were nested inside hashes. (Thanks @apiology)
- Sord now adds `::` when required, to disambiguate nested namespaces from top-level ones. (Thanks
  @sinsoku)

## [6.0.0] - 2023-05-02
### Changed
- **Breaking change**: Now targets RBS 3.0

## [5.1.0] - 2023-05-22
### Added
- Add support for a single `@overload` tag, typically used to describe methods defined outside of
  Ruby. Thanks @ohai!

## [5.0.1] - 2023-05-02
### Fixed
- Use `File#exist?` instead of `File#exists?`, for Ruby 3.2 support. Thanks @matmorel!

## [5.0.0] - 2022-10-06
### Added
- If a derived class does not provide tags for a method, but it is overridden from a base class
  which does, then the base class' documentation will be used to generate types for the derived
  method.
- When generating RBS, if a duck type matches one of RBS' built-in interfaces, this type will be
  generated instead. (For example, `#to_s` will generate the type `_ToS`.)
- Added the `--hide-private` flag, which will omit outputting items with private visibility.
- To improve resolution, types for gems are now loaded from the RBS collection.
- If you are using custom YARD tags, Sord can now be made aware of these by passing the `--tags`
  option.

### Changed
- **Breaking change**: Support for versions of Ruby prior to 2.7 has been dropped.
- When Sord runs YARD automatically, it no longer generates HTML documentation, since this isn't
  necessary for Sord's analysis. If you were relying on this as part of your workflow, then this
  could be a **breaking change**.

### Fixed
- Duck-typed methods ending with `?` or `!`, and operator methods like `#[]=`, are now correctly
  recognised as duck types.
- Fixed an exception when referring to built-in types with root namespace (`::Array<Foo>`) syntax.
- `@yieldparams` without a parameter name no longer cause an exception, and instead use default
  names of the pattern: `arg0`, `arg1`, ...

## [4.0.0] - 2022-07-19
### Added
- Constants are now assigned types when generating RBS, using `@return`.
- Class-level `attr_accessor`s are converted to methods when generating RBS.
- Added the `--exclude-untyped` flag, which skips generating type signatures for methods with
  `untyped` return values.

### Changed
- If YARD tags are present for a block, but there is no block param (such as when using `yield`),
  the type signature now includes the documented block. This could be a **breaking change** leading
  to type errors in existing code where such methods are called.

### Fixed
- Added workaround for YARD syntax error when a default parameter value begins with a unary minus
- Name resolutions from the root (e.g. `::X`) now behave correctly; previously they may have
  selected a class named `X` nested within another namespace. This may be a **breaking change** if
  any part of your generated type signatures was relying on the old, buggy behaviour.

## [3.0.1] - 2020-12-28
### Fixed
- Fixed `SortedSet` crash on Ruby 3
- Fixed incorrect `extend` order on YARD 0.9.26

## [3.0.0] - 2020-12-26
### Added
- Sord now uses the Parlour 5 beta's RBS generation to generate RBS files!
- Added `--rbi` and `--rbs` to select an output format to use (if neither given,
  tries to infer from file extension).

### Changed
- `RbiGenerator` has been renamed to `Generator`.
- `TypeConverter#yard_to_sorbet` is now `TypeConverter#yard_to_parlour`, and
  returns `Parlour::Types::Type` instances rather than strings.

### Fixed
- `#return [nil]` no longer produces a union of zero types, instead becoming
  `void` for method returns or `untyped` for attributes.


<details>
  <summary>3.0.0 pre-releases</summary>

  ## [3.0.0.beta.2] - 2020-10-05
  ### Added
  - Sord is no longer limited to a known set of generics, and will instead
    generate `Parlour::Types::Generic` types for user-defined generics.

  ## [3.0.0.beta.1] - 2020-09-16
  ### Added
  - Sord now uses the Parlour 5 beta's RBS generation to generate RBS files!
  - Added `--rbi` and `--rbs` to select an output format to use (if neither given,
    tries to infer from file extension).

  ### Changed
  - `RbiGenerator` has been renamed to `Generator`.
  - `TypeConverter#yard_to_sorbet` is now `TypeConverter#yard_to_parlour`, and
    returns `Parlour::Types::Type` instances rather than strings.

  ### Fixed
  - `#return [nil]` no longer produces a union of zero types, instead becoming
    `void` for method returns or `untyped` for attributes.

</details>

## [2.0.0] - 2020-03-16
### Added
- Sord now supports generating `attr_accessor`, `attr_reader` and `attr_writer`
and will do so automatically when these are used in your code.
  - Depending on what you're doing with Sord, this is **potentially breaking**,
  as for example attributes which would previously generate two `foo` and `foo=`
  methods in Sord will now just generate an `attr_accessor`.
- `#initialize` is now always typed as returning `void`, which is
**potentially breaking** if you directly call `#initialize` in code.
  - The `--use-original-initialize-return` flag restores the old behaviour of
  using whatever return type is provided, like any other method.

## [1.0.0] - 2020-02-16
### Added
- Added the `--skip-constants` flag to avoid generating RBIs for constants.

### Changed
- Parlour 2.0.0 is now being used.

### Fixed
- Fixed a bug where blank parameters were sometimes treated like non-blank
parameters.
- Fixed parameter order sometimes being incorrect.
- Fixed multiline parameter lists sometimes generating invalid RBIs.
- Multiline comments are now generated correctly.
- Fixed an incorrect README link.

## [0.10.0] - 2019-09-14
### Added
- Comments in RBIs are now converted from YARD into Markdown format, making them
look much better when viewed in an IDE. (To restore the old behaviour of copying
the YARD comments verbatim, use the `--keep-original-comments` flag.)

### Changed
- Parlour 0.8.0 is now being used.
- References to `self` as a type in YARD docs are now generated as
`T.self_type`, rather than a fixed self type determined by Sord.

## [0.9.0] - 2019-08-09
### Added
- Add the `--replace-constants-with-untyped` flag, which generates `T.untyped` instead of `SORD_ERROR` constants.
- Added an option to clean the `sord_examples` directory when seeding or reseeding.
- Added a Rake task to typecheck the `sord_examples` directory.
- Added a `.parlour` file to the project for generating Sord's RBIs.
- Added CI with Travis.

### Changed
- Code generation has been broken out into the Parlour gem, and Sord is now a Parlour plugin.
- Rainbow is now used for coloured output instead of colorize.
- Duplicate type signatures are no longer generated for inherited methods.
- The Resolver can now resolve more objects.
- If a parameter has `nil` as its default, it now has a nilable type.
- Generation of constants has been improved.
- Superclass names are now generated as fully-qualified identifiers.

### Fixed
- Fixed `T::Hash` and `T::Array` syntax being generated incorrectly.
- Fix a bug where the `--no-comments` or `--no-generate` flags were ignored.
- Collections of `T.untyped` now have signatures generated correctly.
- Fix generation of hashes when they are given too few parameters.
- YARD no longer prints irrelevant error messages when running rake.

## [0.8.0] - 2019-07-07
### Added
- Block types can now be generated using `@yieldparam` and `@yieldreturn`.
- Long lists of parameters (at least 4) are now broken onto multiple lines. The threshold can be altered with the `--break-params` option.
- If a constant used is not found, Sord will now attempt to locate it and fully-qualify its name.
- Add the `--replace-errors-with-untyped` flag; when present, `T.untyped` is used instead of `SORD_ERROR_` constants.
- Add the `--include/exclude-messages` flags, which can be used to suppress certain log message kinds.
- Add support for the `Class<...>` generic becoming `T.class_of(...)`. (#44)
- Add YARD array (`<...>`) and hash (`{... => ...}`) shorthands. (#43)
- Sord now has an `examples` set of Rake tasks to test Sord on a large number of repos.
- Sord now bundles an RBI for itself.

### Changed
- Methods without any YARD documentation are now typed as `T.untyped` rather than `void`.

### Fixed
- Duck types in the form of setters (`#foo=`) are now interpreted properly.
- Fix some cases where indentation was incorrect. (#30, #46)
- Fix `include` and `extend` calls being swapped, and give them proper blank lines.
- Fix incorrect blank lines inside empty namespaces.
- Fix a crash when a `@param` has no name given.

## [0.7.1] - 2019-06-24
### Fixed
- Fix bug where `--no-regenerate` flag was ignored.

## [0.7.0] - 2019-06-24
### Added
- A warning message is now shown if the YARD registry has no objects. (#31)
- Integer, Float and Symbol literals are now supported as types. (#26)
- Add support for multi-method YARD duck types. (#38)
- Namespaces are now indented properly. (#41)
- Individual method and namespace counts are now shown, rather than just an overall object count. (#36)

### Changed
- Paths to log message items are now bold rather than white, so that they can be seen on white terminals. (#28)
- Alias methods are now ignored. (#34)
- Remove Gemfile.lock. (#33)
- YARD is executed when Sord is executed. To disable this behaviour, use `--no-regenerate`. (#31)

### Fixed
- Resolved crash when a @return tag gave no type. (#35)

## [0.6.0] - 2019-06-23
### Added
- Namespaces are now nested inside each other in the RBI file, fixing many constant scoping issues. (#25)

### Changed
- Move unfinished tasks from README to GitHub issues.

### Fixed
- Fix typo of 'duck' as 'ducl' (#24)

## [0.5.0] - 2019-06-23
### Added
- Hash rocket syntax for hash types is now supported. (#18)
- Arrays with multiple element types are handled correctly. (#21)

### Fixed
- Move a dependency from Gemfile to Gemspec for consistency. (#19)
- Fix bug where splat-args (`*a`) were always called `args` in signatures. (#20)

## [0.4.1] - 2019-06-22
### Fixed
- The changelog for this version is the same as 0.4.0, but resolving an issue where some changes were not published correctly to RubyGems.

## [0.4.0] - 2019-06-22 [YANKED]
### Added
- Commander is now used for the CLI, which enables a `--help` switch.
- Add a `--no-comments` switch for disabling comments in the RBI file.

### Changed
- Sord now exits as early as possible if no filename is specified. (#17)

### Fixed
- Remove & in block parameter names in signatures, fixing a syntax error in RBIs. (#16)

## [0.3.0] - 2019-06-22
### Added
- `self` now resolves to a type in signatures.
- `true` and `false` are now converted to `T::Boolean` in signatures.
- If a `T.any` contains `nil`, it now instead wraps that part of the signature in a `T.nilable` instead.
- Add GitHub issue templates.

### Changed
- `.vscode` is now git-ignored.
- Method definitions now have a semicolon before the end for consistency with Sorbet's RBIs. (#6)
- `params` is now omitted from signatures if a method has no parameters. (#4)

### Fixed
- Fix kwargs in signatures by removing the duplicate colon from their identifier. (#12)
- Fix kwargs in definitions by not inserting an equal-to symbol for their defaults. (#11)

## [0.2.1] - 2019-06-22
### Fixed
- Fix exception on launch due to forgetting to initialise a class variable. (#1)

## [0.2.0] - 2019-06-22
### Added
- Add RSpec tests.
- Add the Logging class with prettier output.
- Generic types can now take more than one type parameter.
- Add documentation for all classes.
- Add a README.
- Add Sorbet directory and typing mode comments (`srb init`).

### Changed
- Sord now requires a command-line argument to save the RBI to.

## [0.1.0] 2019-06-21
### Added
- First release.

