# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
TODO

## [0.6.0] - 2019-06-23
### Added
- Namespaces are now nested inside eachother in the RBI file, fixing many constant scoping issues. (#25)

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

