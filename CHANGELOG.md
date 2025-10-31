# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-30

### Added
- Initial release of modernized Sumo Logic Fluentd plugin
- Ruby 3.0+ support (drops Ruby 2.x)
- Modern dependency versions:
  - Fluentd 1.16+ (up from no version constraint)
  - `net-http-persistent` 4.0+ (replaces `httpclient`)
  - `oj` 3.16+ for JSON parsing (replaces `yajl`)
- Enhanced security with TLS 1.2+ enforcement
- Comprehensive RSpec test suite
- GitHub Actions CI pipeline for Ruby 3.0, 3.1, 3.2, and 3.3
- RuboCop linting with modern Ruby style guidelines
- SimpleCov for code coverage tracking

### Changed
- Replaced `httpclient` with `net-http-persistent` for better performance and security
- Replaced `yajl` with `oj` for faster and more secure JSON parsing
- Updated all development dependencies to modern versions
- Modernized code style following current Ruby best practices
- Improved error handling and logging
- Enhanced connection pooling and timeout handling

### Removed
- Dropped Ruby 2.x support
- Removed dependency on `httpclient` (known security vulnerabilities)
- Removed dependency on `yajl` (outdated, unmaintained)

### Security
- TLS 1.2+ required by default
- Updated all dependencies to latest secure versions
- Removed vulnerable legacy dependencies

### Migration Notes
This is a modernized fork of `fluent-plugin-sumologic_output` v1.10.0. See README.md for migration instructions.

[unreleased]: https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/releases/tag/v0.1.0
