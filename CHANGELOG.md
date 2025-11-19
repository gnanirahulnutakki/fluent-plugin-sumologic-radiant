# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2025-01-18

### Changed
- Plugin now registers as `sumologic` instead of `sumologic_radiant` for backward compatibility with existing Fluentd configurations
- This allows the plugin to be used with `@type sumologic` in Fluentd config files without requiring config changes

## [0.1.1] - 2025-10-31

### Changed
- Removed contributor attribution from commit history for cleaner repository metadata

## [0.1.0] - 2025-10-30

### Added
- Initial release of modernized Sumo Logic Fluentd plugin
- Ruby 3.0+ support (drops Ruby 2.x)
- Modern dependency versions:
  - Fluentd 1.16+ (up from no version constraint)
  - `net-http-persistent` 4.0+ (replaces `httpclient`)
  - `oj` 3.16+ for JSON parsing (replaces `yajl`)
- Enhanced security with TLS 1.2+ enforcement
- Custom SSL certificate support:
  - `ca_file` parameter for custom CA certificates
  - `ca_path` parameter for CA certificate directories
  - `client_cert` and `client_key` parameters for mutual TLS
- Enhanced debug logging throughout the plugin:
  - Chunk processing statistics
  - SSL configuration details
  - Per-batch send tracking
- Better error messages with actionable information
- Comprehensive RSpec test suite
- GitHub Actions CI pipeline for Ruby 3.0, 3.1, 3.2, and 3.3
- RuboCop linting with modern Ruby style guidelines
- Kubernetes metadata support documentation and examples
- Comprehensive example configurations:
  - Basic configuration
  - Kubernetes logs with metadata
  - Metrics (graphite, carbon2, prometheus)
  - Custom SSL certificates
  - Advanced production setup
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

### Fixed
- **Issue #85**: Added comprehensive warnings when `log_key` is missing for `text` format
  - Startup warning for text/fields log formats
  - Runtime warning showing available record keys
  - Debug logging for dropped record tracking
- **Issue #83**: Eliminated cookie handling warnings by replacing `httpclient` with `net-http-persistent`
- **Issue #38**: Added custom SSL certificate support with `ca_file`, `ca_path`, `client_cert`, and `client_key` parameters
- **Issue #50**: Kubernetes metadata support through modern Fluentd's `$.field.subfield` syntax
- **Issue #84**: Buffer configuration fully compatible with modern Fluentd standards
- **Issue #72**: Plugin properly recognized through correct registration structure

### Security
- TLS 1.2+ required by default
- Updated all dependencies to latest secure versions
- Removed vulnerable legacy dependencies

### Migration Notes
This is a modernized fork of `fluent-plugin-sumologic_output` v1.10.0. See README.md for migration instructions.

[unreleased]: https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/releases/tag/v0.1.0
