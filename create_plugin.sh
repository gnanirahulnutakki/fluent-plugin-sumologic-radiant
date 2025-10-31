#!/bin/bash
# Script to create fluent-plugin-sumologic-radiant structure efficiently

echo "Creating modernized Sumo Logic Fluentd plugin..."

# Copy and adapt files from Splunk plugin as template since structure is similar
cd /Users/nutakki/Documents/cloud-2025/documents

# Copy structure from splunk plugin
cp fluent-plugin-splunk-hec-radiant/.ruby-version fluent-plugin-sumologic-radiant/
cp fluent-plugin-splunk-hec-radiant/.gitignore fluent-plugin-sumologic-radiant/
cp fluent-plugin-splunk-hec-radiant/.rspec fluent-plugin-sumologic-radiant/
cp fluent-plugin-splunk-hec-radiant/.rubocop.yml fluent-plugin-sumologic-radiant/
cp fluent-plugin-splunk-hec-radiant/Rakefile fluent-plugin-sumologic-radiant/
cp fluent-plugin-splunk-hec-radiant/spec/spec_helper.rb fluent-plugin-sumologic-radiant/spec/
cp fluent-plugin-splunk-hec-radiant/.github/workflows/ci.yml fluent-plugin-sumologic-radiant/.github/workflows/

# Copy LICENSE from original sumologic
cp /tmp/sumologic-reference/LICENSE fluent-plugin-sumologic-radiant/

echo "✅ Base structure created"
