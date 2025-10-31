# frozen_string_literal: true

require "fluent/plugin/output"
require "net/http/persistent"
require "oj"
require "zlib"
require "stringio"
require "uri"
require "openssl"

module Fluent
  module Plugin
    # Connection handler for Sumo Logic HTTP endpoint
    class SumologicConnection
      attr_reader :http

      COMPRESS_DEFLATE = "deflate"
      COMPRESS_GZIP = "gzip"

      def initialize(endpoint, verify_ssl, connect_timeout, send_timeout, receive_timeout, proxy_uri,
                     disable_cookies, sumo_client, compress_enabled, compress_encoding, logger)
        @endpoint = URI.parse(endpoint)
        @sumo_client = sumo_client
        @logger = logger
        @compress = compress_enabled
        @compress_encoding = (compress_encoding || COMPRESS_GZIP).downcase

        unless [COMPRESS_DEFLATE, COMPRESS_GZIP].include?(@compress_encoding)
          raise ArgumentError, "Invalid compression encoding #{@compress_encoding} must be gzip or deflate"
        end

        create_http_client(verify_ssl, connect_timeout, send_timeout, receive_timeout, proxy_uri, disable_cookies)
      end

      def publish(raw_data, source_host: nil, source_category: nil, source_name: nil, data_type: nil,
                  metric_data_format: nil, collected_fields: nil, dimensions: nil)
        request = Net::HTTP::Post.new(@endpoint.request_uri)
        request_headers(source_host, source_category, source_name, data_type, metric_data_format,
                        collected_fields, dimensions).each do |key, value|
          request[key] = value
        end
        request.body = compress(raw_data)

        response = @http.request(@endpoint, request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Failed to send data to HTTP Source. #{response.code} - #{response.body}"
        end

        # response is 20x, check response content
        return if response.body.nil? || response.body.empty?

        # if we get a non-empty response, check it
        begin
          response_map = Oj.load(response.body)
        rescue Oj::ParseError => e
          @logger.warn "Error decoding receiver response: #{response.body} (#{e.message})"
          return
        end

        # log a warning with the present keys
        response_keys = %w[id code status message errors]
        log_params = response_keys.filter_map do |key|
          "#{key}: #{response_map[key]}" if response_map.key?(key)
        end
        @logger.warn "There was an issue sending data: #{log_params.join(', ')}" if log_params.any?
      end

      private

      def request_headers(source_host, source_category, source_name, data_type, metric_data_format,
                          collected_fields, dimensions)
        headers = {
          "X-Sumo-Name" => source_name,
          "X-Sumo-Category" => source_category,
          "X-Sumo-Host" => source_host,
          "X-Sumo-Client" => @sumo_client
        }

        headers["Content-Encoding"] = @compress_encoding if @compress

        if data_type == "metrics"
          headers["Content-Type"] = case metric_data_format
                                    when "graphite"
                                      "application/vnd.sumologic.graphite"
                                    when "carbon2"
                                      "application/vnd.sumologic.carbon2"
                                    when "prometheus"
                                      "application/vnd.sumologic.prometheus"
                                    else
                                      raise ArgumentError,
                                            "Invalid metric format #{metric_data_format}, " \
                                            "must be graphite, carbon2, or prometheus"
                                    end

          headers["X-Sumo-Dimensions"] = dimensions unless dimensions.nil?
        end

        headers["X-Sumo-Fields"] = collected_fields unless collected_fields.nil?
        headers
      end

      def create_http_client(verify_ssl, connect_timeout, send_timeout, receive_timeout, proxy_uri, disable_cookies)
        @http = Net::HTTP::Persistent.new(name: "fluent_sumologic_radiant")
        @http.proxy = URI.parse(proxy_uri) if proxy_uri
        @http.open_timeout = connect_timeout
        @http.read_timeout = receive_timeout
        @http.write_timeout = send_timeout
        @http.idle_timeout = 5
        @http.max_requests = 1000

        # SSL configuration
        @http.verify_mode = verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        @http.min_version = OpenSSL::SSL::TLS1_2_VERSION if verify_ssl

        # Cookie management - net-http-persistent doesn't have built-in cookie support
        # This is handled differently than httpclient
        @logger.info "Cookie handling is managed by Net::HTTP (no special configuration needed)" if disable_cookies
      end

      def compress(content)
        return content unless @compress

        if @compress_encoding == COMPRESS_GZIP
          gzip(content)
        else
          Zlib::Deflate.deflate(content)
        end
      end

      def gzip(content)
        stream = StringIO.new
        stream.set_encoding("ASCII-8BIT")
        gz = Zlib::GzipWriter.new(stream)
        gz.mtime = 1 # Ensure that for same content there is same output
        gz.write(content)
        gz.close
        stream.string
      end
    end

    # Main Sumologic output plugin
    class SumologicRadiantOutput < Output
      Fluent::Plugin.register_output("sumologic_radiant", self)

      helpers :compat_parameters

      DEFAULT_BUFFER_TYPE = "memory"
      LOGS_DATA_TYPE = "logs"
      METRICS_DATA_TYPE = "metrics"
      DEFAULT_DATA_TYPE = LOGS_DATA_TYPE
      DEFAULT_METRIC_FORMAT_TYPE = "graphite"

      config_param :data_type, :string, default: DEFAULT_DATA_TYPE
      config_param :metric_data_format, :string, default: DEFAULT_METRIC_FORMAT_TYPE
      config_param :endpoint, :string, secret: true
      config_param :log_format, :string, default: "json"
      config_param :log_key, :string, default: "message"
      config_param :source_category, :string, default: nil
      config_param :source_name, :string, default: nil
      config_param :source_name_key, :string, default: "source_name"
      config_param :source_host, :string, default: nil
      config_param :verify_ssl, :bool, default: true
      config_param :delimiter, :string, default: "."
      config_param :open_timeout, :integer, default: 60
      config_param :receive_timeout, :integer, default: 60
      config_param :send_timeout, :integer, default: 120
      config_param :add_timestamp, :bool, default: true
      config_param :timestamp_key, :string, default: "timestamp"
      config_param :proxy_uri, :string, default: nil
      config_param :disable_cookies, :bool, default: false

      config_param :use_internal_retry, :bool, default: false
      config_param :retry_timeout, :time, default: 72 * 3600 # 72h
      config_param :retry_max_times, :integer, default: 0
      config_param :retry_min_interval, :time, default: 1 # 1s
      config_param :retry_max_interval, :time, default: 5 * 60 # 5m

      config_param :max_request_size, :size, default: 0

      desc "Fields string (eg 'cluster=payment, service=credit_card') which is going to be added to every log record."
      config_param :custom_fields, :string, default: nil
      desc "Name of sumo client which is sent as X-Sumo-Client header"
      config_param :sumo_client, :string, default: "fluentd-output"
      desc "Compress payload"
      config_param :compress, :bool, default: true
      desc "Encoding method of compression (either gzip or deflate)"
      config_param :compress_encoding, :string, default: SumologicConnection::COMPRESS_GZIP
      desc "Dimensions string (eg 'cluster=payment, service=credit_card') added to every metric record."
      config_param :custom_dimensions, :string, default: nil
      desc "Key to extract metadata from record (e.g., '_sumo_metadata')"
      config_param :sumo_metadata_key, :string, default: nil

      config_section :buffer do
        config_set_default :@type, DEFAULT_BUFFER_TYPE
        config_set_default :chunk_keys, ["tag"]
      end

      def multi_workers_ready?
        true
      end

      def configure(conf)
        compat_parameters_convert(conf, :buffer)
        super

        begin
          uri = URI.parse(@endpoint)
          unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
            raise Fluent::ConfigError, "Invalid SumoLogic endpoint url: #{@endpoint}"
          end
        rescue URI::InvalidURIError
          raise Fluent::ConfigError, "Invalid SumoLogic endpoint url: #{@endpoint}"
        end

        unless @data_type.match?(/\A(?:logs|metrics)\z/)
          raise Fluent::ConfigError, "Invalid data_type #{@data_type} must be logs or metrics"
        end

        if @data_type == LOGS_DATA_TYPE && !@log_format.match?(/\A(?:json|text|json_merge|fields)\z/)
          raise Fluent::ConfigError, "Invalid log_format #{@log_format} must be text, json, json_merge or fields"
        end

        if @data_type == METRICS_DATA_TYPE && !@metric_data_format.match?(/\A(?:graphite|carbon2|prometheus)\z/)
          raise Fluent::ConfigError,
                "Invalid metric_data_format #{@metric_data_format} must be graphite, carbon2, or prometheus"
        end

        @custom_fields = validate_key_value_pairs(@custom_fields)
        log.debug "Custom fields: #{@custom_fields}" if @custom_fields

        @custom_dimensions = validate_key_value_pairs(@custom_dimensions)
        log.debug "Custom dimensions: #{@custom_dimensions}" if @custom_dimensions

        @sumo_conn = SumologicConnection.new(
          @endpoint,
          @verify_ssl,
          @open_timeout,
          @send_timeout,
          @receive_timeout,
          @proxy_uri,
          @disable_cookies,
          @sumo_client,
          @compress,
          @compress_encoding,
          log
        )
      end

      def start
        super
      end

      def shutdown
        super
        @sumo_conn&.http&.shutdown
      end

      # Used to merge log record into top level json
      def merge_json(record)
        return record unless record.key?(@log_key)

        log_value = record[@log_key].strip
        if log_value.start_with?("{") && log_value.end_with?("}")
          begin
            parsed = Oj.load(log_value)
            record = record.merge(parsed)
            record.delete(@log_key)
          rescue Oj::ParseError
            # do nothing, ignore
          end
        end
        record
      end

      # Strip sumo_metadata and dump to json
      def dump_log(log_record)
        log_record.delete("_sumo_metadata")
        begin
          if log_record.key?(@log_key)
            hash = Oj.load(log_record[@log_key])
            log_record[@log_key] = hash
          end
        rescue Oj::ParseError
          # Keep original if parsing fails
        end
        Oj.dump(log_record)
      end

      def format(tag, time, record)
        mstime = if time.respond_to?(:nsec)
                   time.to_i * 1000 + (time.nsec / 1_000_000)
                 else
                   time.to_i * 1000
                 end
        [mstime, record].to_msgpack
      end

      def formatted_to_msgpack_binary?
        true
      end

      def sumo_key(sumo_metadata, chunk)
        source_name = sumo_metadata["source"] || @source_name
        source_name = extract_placeholders(source_name, chunk) unless source_name.nil?

        source_category = sumo_metadata["category"] || @source_category
        source_category = extract_placeholders(source_category, chunk) unless source_category.nil?

        source_host = sumo_metadata["host"] || @source_host
        source_host = extract_placeholders(source_host, chunk) unless source_host.nil?

        fields = sumo_metadata["fields"] || ""
        fields = extract_placeholders(fields, chunk) unless fields.nil?

        {
          source_name: source_name.to_s,
          source_category: source_category.to_s,
          source_host: source_host.to_s,
          fields: fields.to_s
        }
      end

      # Convert timestamp to 13 digit epoch if necessary
      def sumo_timestamp(time)
        time.to_s.length == 13 ? time : time * 1000
      end

      # Convert log to string and strip it
      def log_to_str(log_value)
        log_value = Oj.dump(log_value) if log_value.is_a?(Array) || log_value.is_a?(Hash)
        log_value&.strip
      end

      def write(chunk)
        messages_list = {}

        # Sort messages
        chunk.msgpack_each do |time, record|
          next unless record.is_a?(Hash)

          sumo_metadata = if @sumo_metadata_key && record.key?(@sumo_metadata_key)
                            record.fetch(@sumo_metadata_key, {})
                          else
                            record.fetch("_sumo_metadata", { source: record[@source_name_key] })
                          end

          key = sumo_key(sumo_metadata, chunk)
          log_format = sumo_metadata["log_format"] || @log_format

          # Strip any unwanted newlines
          record[@log_key]&.chomp! if record[@log_key]&.respond_to?(:chomp!)

          log = case @data_type
                when "logs"
                  format_log(record, log_format, time)
                when "metrics"
                  log_to_str(record[@log_key])
                end

          next if log.nil?

          messages_list[key] ||= []
          messages_list[key].push(log)
        end

        chunk_id = "##{chunk.dump_unique_id_hex(chunk.unique_id)}"
        send_messages(messages_list, chunk_id)
      end

      private

      def format_log(record, log_format, time)
        case log_format
        when "text"
          unless record.key?(@log_key)
            log.warn "log key `#{@log_key}` has not been found in the log"
            return nil
          end
          log_to_str(record[@log_key])
        when "json_merge"
          record = { @timestamp_key => sumo_timestamp(time) }.merge(record) if @add_timestamp
          dump_log(merge_json(record))
        when "fields"
          record = { @timestamp_key => sumo_timestamp(time) }.merge(record) if @add_timestamp
          dump_log(record)
        else # json
          record = { @timestamp_key => sumo_timestamp(time) }.merge(record) if @add_timestamp
          dump_log(record)
        end
      end

      def send_messages(messages_list, chunk_id)
        messages_list.each do |key, messages|
          source_name = key[:source_name]
          source_category = key[:source_category]
          source_host = key[:source_host]
          fields = key[:fields]

          # Merge custom and record fields
          fields = if fields.nil? || fields.strip.empty?
                     @custom_fields
                   else
                     [fields, @custom_fields].compact.join(",")
                   end

          messages_to_send = split_messages_by_size(messages)

          messages_to_send.each_with_index do |message_batch, i|
            send_batch_with_retry(message_batch, source_name, source_category, source_host,
                                  fields, chunk_id, i)
          end
        end
      end

      def split_messages_by_size(messages)
        return [messages] if @max_request_size <= 0

        messages_to_send = []
        current_message = []
        current_length = 0

        messages.each do |message|
          current_message.push(message)
          current_length += message.length

          if current_length > @max_request_size
            messages_to_send.push(current_message)
            current_message = []
            current_length = 0
          end
          current_length += 1 # newline character
        end

        messages_to_send.push(current_message) if current_message.any?
        messages_to_send
      end

      def send_batch_with_retry(message_batch, source_name, source_category, source_host, fields, chunk_id, batch_index)
        retries = 0
        start_time = Time.now
        sleep_time = @retry_min_interval

        loop do
          common_log_part = "#{@data_type} records with source category '#{source_category}', " \
                            "source host '#{source_host}', source name '#{source_name}', " \
                            "chunk #{chunk_id}, try #{retries}, batch #{batch_index}"

          begin
            log.debug { "Sending #{message_batch.count}; #{common_log_part}" }

            @sumo_conn.publish(
              message_batch.join("\n"),
              source_host: source_host,
              source_category: source_category,
              source_name: source_name,
              data_type: @data_type,
              metric_data_format: @metric_data_format,
              collected_fields: fields,
              dimensions: @custom_dimensions
            )
            break
          rescue StandardError => e
            raise e unless @use_internal_retry

            retries += 1
            log.warn "error while sending request to sumo: #{e}; #{common_log_part}"
            log.warn_backtrace e.backtrace

            # Drop data if we exceeded retry limits
            if (retries >= @retry_max_times && @retry_max_times.positive?) ||
               (Time.now > start_time + @retry_timeout && @retry_timeout.positive?)
              log.warn "dropping records; #{common_log_part}"
              break
            end

            log.info "going to retry to send data at #{Time.now + sleep_time}; #{common_log_part}"
            sleep sleep_time

            sleep_time *= 2
            sleep_time = @retry_max_interval if sleep_time > @retry_max_interval
          end
        end
      end

      def validate_key_value_pairs(fields)
        return nil if fields.nil?

        validated = fields.split(",").select do |field|
          field.split("=").length == 2
        end

        return nil if validated.empty?

        validated.join(",")
      end
    end
  end
end
