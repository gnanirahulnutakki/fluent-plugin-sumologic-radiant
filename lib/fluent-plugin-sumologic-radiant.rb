# frozen_string_literal: true

require_relative "fluent/plugin/sumologic_radiant/version"
require_relative "fluent/plugin/out_sumologic_radiant"

module Fluent
  module Plugin
    module SumologicRadiant
      class Error < StandardError; end
    end
  end
end
