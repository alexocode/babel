# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
### Changed
### Fixed
### Removed

## [1.2.0]
### Added
- Add a custom `depth` inspect option for `Babel.Trace`s which controls how many nested traces should be rendered [@alexocode]
- Add a `Babel.Trace.reduce/2` function that reduces over the trace and all nested traces [@alexocode]
- Add a `Babel.Trace.inspect/2` function as a shortcut for `inspect(<trace>, custom_options: <opts>)` [@alexocode]

### Changed
- Change the default `inspect` behaviour for `Babel.Trace`s to omit all nested traces [@alexocode]

## [1.1.0]
### Changed
- Reduce noise in error traces by omitting successful traces [@alexocode]

## [1.0.1]
Improve docs and gracefully handle `nil` when fetching paths.

## [1.0.0]
First release of Babel with a stable API.

[Unreleased]: https://github.com/alexocode/babel/compare/v1.2.0...main
[1.2.0]: https://github.com/alexocode/babel/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/alexocode/babel/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/alexocode/babel/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/alexocode/babel/compare/176373951df796ded497645fc36409090c489be1...v1.0.0

[@alexocode]: https://github.com/alexocode
