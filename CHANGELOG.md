# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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

