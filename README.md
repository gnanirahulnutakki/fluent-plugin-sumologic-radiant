# fluent-plugin-sumologic-radiant

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-sumologic-radiant.svg)](https://badge.fury.io/rb/fluent-plugin-sumologic-radiant)
[![Downloads](https://img.shields.io/gem/dt/fluent-plugin-sumologic-radiant.svg)](https://rubygems.org/gems/fluent-plugin-sumologic-radiant)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Ruby](https://img.shields.io/badge/ruby-3.0+-red.svg)](https://www.ruby-lang.org)
[![CI](https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/actions/workflows/ci.yml/badge.svg)](https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/actions/workflows/ci.yml)

A **modernized and actively maintained** Fluentd output plugin for sending logs and metrics to [Sumo Logic](https://www.sumologic.com) via the [HTTP Collector API](https://help.sumologic.com/docs/send-data/hosted-collectors/http-source/).

This is a fork of the original [fluent-plugin-sumologic_output](https://github.com/SumoLogic/fluentd-output-sumologic) by Sumo Logic Inc. This version includes:

- ✅ **Ruby 3.x support** (requires Ruby 3.0+)
- ✅ **Modern dependencies** (Fluentd 1.16+, latest gems)
- ✅ **Better performance** (using `oj` for JSON, `net-http-persistent` for connections)
- ✅ **Enhanced security** (TLS 1.2+ by default, custom SSL certificates, updated dependencies)
- ✅ **Bug fixes** from original plugin (see [Fixed Issues](#fixed-issues-from-original-plugin) below)
- ✅ **Enhanced debugging** with better error messages and logging
- ✅ **Active maintenance** and vulnerability management
- ✅ **Comprehensive test coverage**

## Installation

### RubyGems

```bash
gem install fluent-plugin-sumologic-radiant
```

### Bundler

Add to your `Gemfile`:

```ruby
gem "fluent-plugin-sumologic-radiant"
```

Then run:

```bash
bundle install
```

### td-agent

```bash
td-agent-gem install fluent-plugin-sumologic-radiant
```

## Configuration

The plugin is registered as `@type sumologic_radiant`.

### Basic Configuration

```xml
<match **>
  @type sumologic_radiant
  endpoint https://[SumoEndpoint]/receiver/v1/http/[UniqueHTTPCollectorCode]
  log_format json
  source_category my_category
  source_name my_source
  source_host my_host
</match>
```

### Full Configuration Example

```xml
<match **>
  @type sumologic_radiant

  # HTTP Collector endpoint (required)
  endpoint https://collectors.sumologic.com/receiver/v1/http/XXXXX

  # Source metadata
  source_category production/app/logs
  source_name ${tag}
  source_host ${hostname}

  # Log formatting
  log_format json          # text, json, json_merge, or fields (default: json)
  log_key message          # Field to use as log message (when log_format is fields)
  open_timeout 60
  add_timestamp true
  timestamp_key timestamp

  # Compression
  compress true            # Enable gzip compression (default: false)
  compress_encoding gzip   # gzip or deflate (default: gzip)

  # Custom fields
  custom_fields department=engineering,application=myapp
  custom_dimensions cluster=prod,region=us-east

  # Proxy configuration
  proxy_uri http://proxy.example.com:8080

  # SSL/TLS
  verify_ssl true          # Verify SSL certificates (default: true)

  # Performance tuning
  disable_cookies true     # Disable cookie handling (default: false)

  # Metadata extraction
  sumo_metadata_key _sumo_metadata  # Extract metadata from this field
</match>
```

### Sending Metrics

To send metrics to Sumo Logic (requires a metrics HTTP source):

```xml
<match metrics.**>
  @type sumologic_radiant
  endpoint https://collectors.sumologic.com/receiver/v1/http/XXXXX
  data_type metrics
  metric_data_format graphite  # graphite, carbon2, or prometheus (default: graphite)
  source_category production/metrics

  # Optional: Add dimensions to all metrics
  custom_dimensions cluster=prod,service=api
</match>
```

#### Metric Formats

**Graphite format:**
```
metric.path value timestamp
```

**Carbon2 format:**
```
metric=value field1=value1 field2=value2 timestamp
```

**Prometheus format:**
```
# TYPE metric_name gauge
metric_name{label1="value1"} value timestamp
```

## Configuration Parameters

### Basic Parameters

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `endpoint` | string | - | **Yes** | Sumo Logic HTTP collector endpoint URL |
| `data_type` | enum | `logs` | No | Data type: `logs` or `metrics` |
| `log_format` | enum | `json` | No | Log format: `text`, `json`, `json_merge`, or `fields` |
| `metric_data_format` | enum | `graphite` | No | Metric format: `graphite`, `carbon2`, or `prometheus` |

### Source Metadata

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source_category` | string | - | Source category for Sumo Logic |
| `source_name` | string | - | Source name for Sumo Logic |
| `source_host` | string | hostname | Source host for Sumo Logic |
| `source_category_key` | string | - | Extract source category from this field |
| `source_name_key` | string | - | Extract source name from this field |
| `source_host_key` | string | - | Extract source host from this field |

### Custom Fields and Dimensions

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `custom_fields` | string | - | Comma-separated key=value pairs for custom fields |
| `custom_dimensions` | string | - | Comma-separated key=value pairs for custom dimensions (metrics only) |

### Compression

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `compress` | bool | `false` | Enable compression |
| `compress_encoding` | enum | `gzip` | Compression type: `gzip` or `deflate` |

### SSL/TLS

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `verify_ssl` | bool | `true` | Verify SSL certificates |
| `ca_file` | string | - | Path to CA certificate file for SSL verification |
| `ca_path` | string | - | Path to CA certificate directory for SSL verification |
| `client_cert` | string | - | Path to client certificate file for mutual TLS |
| `client_key` | string | - | Path to client private key file for mutual TLS |

### Connection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connect_timeout` | integer | `1` | Connection timeout in seconds |
| `send_timeout` | integer | `120` | Send timeout in seconds |
| `receive_timeout` | integer | `60` | Receive timeout in seconds |
| `open_timeout` | integer | `60` | Open timeout in seconds |
| `proxy_uri` | string | - | HTTP proxy URI |
| `disable_cookies` | bool | `false` | Disable cookie handling |

### Advanced

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `add_timestamp` | bool | `true` | Add timestamp to logs |
| `timestamp_key` | string | `timestamp` | Timestamp field name |
| `log_key` | string | `message` | Log message field (for `fields` format) |
| `sumo_metadata_key` | string | - | Extract metadata from this field |

## Dynamic Metadata with `_sumo_metadata`

You can override source metadata on a per-record basis using the `_sumo_metadata` field:

```ruby
{
  "message" => "Application error",
  "_sumo_metadata" => {
    "category" => "errors/application",
    "host" => "webserver-01",
    "source" => "app.log"
  }
}
```

Enable this feature by setting `sumo_metadata_key`:

```xml
<match **>
  @type sumologic_radiant
  endpoint https://collectors.sumologic.com/receiver/v1/http/XXXXX
  sumo_metadata_key _sumo_metadata
</match>
```

## Migration from fluent-plugin-sumologic_output

This plugin is designed as a **drop-in replacement** for the original `fluent-plugin-sumologic_output`. To migrate:

1. **Update your Gemfile or installation**:
   ```ruby
   # Old
   # gem "fluent-plugin-sumologic_output"

   # New
   gem "fluent-plugin-sumologic-radiant"
   ```

2. **Update your Fluentd configuration**:
   ```xml
   <match **>
     # Old
     # @type sumologic

     # New
     @type sumologic_radiant

     # ... rest of configuration remains the same
   </match>
   ```

3. **Verify Ruby version**: Ensure you're running Ruby 3.0 or newer.

### Breaking Changes

- **Ruby 2.x is no longer supported** - Ruby 3.0+ is required
- **TLS 1.0/1.1 disabled by default** - TLS 1.2+ is enforced
- **Dependency changes**: Uses `oj` instead of `yajl`, `net-http-persistent` instead of `httpclient`

## Fixed Issues from Original Plugin

This modernized version fixes several issues reported in the original plugin:

### Issue #85: Missing log_key Warning
**Problem**: When using `log_format=text` without the correct `log_key`, logs would silently stop being sent.

**Fix**: Added comprehensive warnings at both startup and runtime:
- Startup warning when `log_format` is set to `text` or `fields`
- Runtime warning showing available record keys when `log_key` is missing
- Enhanced debug logging to track processed vs. dropped records

### Issue #83: Cookie Handling Warnings
**Problem**: The original plugin using `httpclient` would spam logs with "Unknown key: MAX-AGE" and "Unknown key: SameSite" warnings.

**Fix**: Replaced `httpclient` with `net-http-persistent`, which handles modern cookie attributes properly and eliminates these noisy warnings entirely.

### Issue #38: Custom SSL Certificates
**Problem**: No support for custom CA certificates or client certificate authentication.

**Fix**: Added full SSL/TLS customization:
- `ca_file` - Custom CA certificate file
- `ca_path` - Custom CA certificate directory
- `client_cert` / `client_key` - Mutual TLS support

These options allow secure connections with internal PKI, self-signed certificates, or enterprise certificate requirements.

### Enhanced Debugging
Added detailed debug logging throughout the plugin:
- Chunk processing statistics (processed, dropped, sent counts)
- SSL configuration details
- Connection initialization messages
- Per-batch send tracking with retry information

## Log Formats

### `text` Format
Sends the entire record as plain text.

### `json` Format (Default)
Sends the record as JSON:
```json
{"field1": "value1", "field2": "value2"}
```

### `json_merge` Format
Merges a specific field with the record:
```xml
<match **>
  @type sumologic_radiant
  log_format json_merge
  log_key log
</match>
```

### `fields` Format
Extracts a specific field as the message:
```xml
<match **>
  @type sumologic_radiant
  log_format fields
  log_key message
</match>
```

## Development

### Prerequisites

- Ruby 3.0 or newer
- Bundler 2.0+
- Git

### Setup

```bash
git clone https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant.git
cd fluent-plugin-sumologic-radiant
bundle install
```

### Running Tests

```bash
bundle exec rspec
```

### Linting

```bash
bundle exec rubocop
```

### Building the Gem

```bash
bundle exec rake build
```

The gem will be created in the `pkg/` directory.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- Tests pass (`bundle exec rspec`)
- Code passes linting (`bundle exec rubocop`)
- New features include tests
- Documentation is updated

## License

Copyright 2025 G. Rahul Nutakki
Copyright 2016-2024 Sumo Logic Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Attribution

This project is a derivative work of [fluent-plugin-sumologic_output](https://github.com/SumoLogic/fluentd-output-sumologic) by Sumo Logic Inc. See [NOTICE](NOTICE) for full attribution details.

## Support

- **Issues**: [GitHub Issues](https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/issues)
- **Documentation**: [README.md](https://github.com/gnanirahulnutakki/fluent-plugin-sumologic-radiant/blob/main/README.md)
- **Original Plugin**: [fluent-plugin-sumologic_output](https://github.com/SumoLogic/fluentd-output-sumologic)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
