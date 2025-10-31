# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fluent::Plugin::SumologicRadiantOutput do
  let(:driver) { Fluent::Test::Driver::Output.new(described_class) }
  let(:endpoint) { "https://collectors.sumologic.com/receiver/v1/http/test" }

  describe "configuration" do
    it "loads the plugin" do
      driver.configure("endpoint #{endpoint}")
      expect(driver.instance).to be_a(described_class)
    end

    it "requires an endpoint" do
      expect { driver.configure("") }.to raise_error(Fluent::ConfigError)
    end

    it "validates endpoint URL format" do
      expect do
        driver.configure("endpoint invalid-url")
      end.to raise_error(Fluent::ConfigError, /Invalid SumoLogic endpoint url/)
    end

    it "accepts valid data_type values" do
      driver.configure("endpoint #{endpoint}\ndata_type logs")
      expect(driver.instance.data_type).to eq("logs")

      driver.configure("endpoint #{endpoint}\ndata_type metrics")
      expect(driver.instance.data_type).to eq("metrics")
    end

    it "rejects invalid data_type values" do
      expect do
        driver.configure("endpoint #{endpoint}\ndata_type invalid")
      end.to raise_error(Fluent::ConfigError, /Invalid data_type/)
    end

    it "accepts valid log_format values for logs" do
      %w[json text json_merge fields].each do |format|
        driver.configure("endpoint #{endpoint}\ndata_type logs\nlog_format #{format}")
        expect(driver.instance.log_format).to eq(format)
      end
    end

    it "rejects invalid log_format values" do
      expect do
        driver.configure("endpoint #{endpoint}\ndata_type logs\nlog_format invalid")
      end.to raise_error(Fluent::ConfigError, /Invalid log_format/)
    end

    it "accepts valid metric_data_format values for metrics" do
      %w[graphite carbon2 prometheus].each do |format|
        driver.configure("endpoint #{endpoint}\ndata_type metrics\nmetric_data_format #{format}")
        expect(driver.instance.metric_data_format).to eq(format)
      end
    end

    it "rejects invalid metric_data_format values" do
      expect do
        driver.configure("endpoint #{endpoint}\ndata_type metrics\nmetric_data_format invalid")
      end.to raise_error(Fluent::ConfigError, /Invalid metric_data_format/)
    end

    it "sets default values" do
      driver.configure("endpoint #{endpoint}")
      instance = driver.instance

      expect(instance.data_type).to eq("logs")
      expect(instance.log_format).to eq("json")
      expect(instance.metric_data_format).to eq("graphite")
      expect(instance.verify_ssl).to be true
      expect(instance.compress).to be true
      expect(instance.add_timestamp).to be true
      expect(instance.sumo_client).to eq("fluentd-output")
    end

    it "parses custom_fields correctly" do
      driver.configure("endpoint #{endpoint}\ncustom_fields cluster=prod,app=myapp")
      expect(driver.instance.custom_fields).to eq("cluster=prod,app=myapp")
    end

    it "parses custom_dimensions correctly" do
      driver.configure("endpoint #{endpoint}\ncustom_dimensions cluster=prod,region=us")
      expect(driver.instance.custom_dimensions).to eq("cluster=prod,region=us")
    end

    it "validates custom_fields format" do
      driver.configure("endpoint #{endpoint}\ncustom_fields invalid_format")
      expect(driver.instance.custom_fields).to be_nil
    end
  end

  describe "#multi_workers_ready?" do
    it "returns true" do
      driver.configure("endpoint #{endpoint}")
      expect(driver.instance.multi_workers_ready?).to be true
    end
  end

  describe "SumologicConnection" do
    let(:logger) { instance_double(Fluent::Log) }
    let(:connection) do
      Fluent::Plugin::SumologicConnection.new(
        endpoint,
        true, # verify_ssl
        60,   # connect_timeout
        120,  # send_timeout
        60,   # receive_timeout
        nil,  # proxy_uri
        false, # disable_cookies
        "test-client",
        true, # compress
        "gzip",
        logger
      )
    end

    before do
      allow(logger).to receive(:warn)
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
    end

    describe "#initialize" do
      it "creates a connection with gzip compression" do
        expect(connection).to be_a(Fluent::Plugin::SumologicConnection)
      end

      it "rejects invalid compression encoding" do
        expect do
          Fluent::Plugin::SumologicConnection.new(
            endpoint, true, 60, 120, 60, nil, false, "test", true, "invalid", logger
          )
        end.to raise_error(ArgumentError, /Invalid compression encoding/)
      end
    end

    describe "#publish" do
      let(:success_response) { Net::HTTPOK.new("1.1", "200", "OK") }

      before do
        allow(success_response).to receive(:body).and_return("")
        stub_request(:post, endpoint)
          .to_return(status: 200, body: "", headers: {})
      end

      it "publishes data successfully" do
        expect do
          connection.publish(
            "test data",
            source_host: "testhost",
            source_category: "testcat",
            source_name: "testname",
            data_type: "logs",
            metric_data_format: "graphite",
            collected_fields: nil,
            dimensions: nil
          )
        end.not_to raise_error
      end

      it "raises error on HTTP failure" do
        stub_request(:post, endpoint)
          .to_return(status: 400, body: "Error message", headers: {})

        expect do
          connection.publish(
            "test data",
            source_host: "testhost",
            source_category: "testcat",
            source_name: "testname",
            data_type: "logs",
            metric_data_format: "graphite",
            collected_fields: nil,
            dimensions: nil
          )
        end.to raise_error(/Failed to send data/)
      end
    end
  end
end
