# frozen_string_literal: true

# Copyright 2019 OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require_relative '../../test_helper'

require_relative '../../../lib/opentelemetry/instrumentation/active_model_serializers/instrumentation'

describe OpenTelemetry::Instrumentation::ActiveModelSerializers do
  let(:instrumentation) { OpenTelemetry::Instrumentation::ActiveModelSerializers::Instrumentation.instance }
  let(:exporter) { EXPORTER }

  before do
    instrumentation.install
    exporter.reset
  end

  describe 'present' do
    it 'when active_model_serializers gem installed' do
      _(instrumentation.present?).must_equal true
    end

    it 'when active_model_serializers gem not installed' do
      hide_const('ActiveModelSerializers')
      _(instrumentation.present?).must_equal false
    end

    it 'when older gem version installed' do
      allow_any_instance_of(Bundler::StubSpecification).to receive(:version).and_return(Gem::Version.new('2.4.3'))
      _(instrumentation.present?).must_equal false
    end

    it 'when future gem version installed' do
      allow_any_instance_of(Bundler::StubSpecification).to receive(:version).and_return(Gem::Version.new('3.0.0'))
      _(instrumentation.present?).must_equal true
    end
  end

  describe 'install' do
    it 'installs the subscriber' do
      klass = OpenTelemetry::Instrumentation::ActiveModelSerializers::Subscriber
      subscribers = Mongo::Monitoring::Global.subscribers['Command']
      _(subscribers.size).must_equal 1
      _(subscribers.first).must_be_kind_of klass
    end
  end

  describe 'tracing' do
    before do
      TestHelper.setup_active_model_serializers
    end

    after do
      TestHelper.teardown_active_model_serializers
    end

    it 'before job' do
      _(exporter.finished_spans.size).must_equal 0
    end

    it 'after job' do
      client = TestHelper.client

      client['people'].insert_one(name: 'Steve', hobbies: ['hiking'])
      _(exporter.finished_spans.size).must_equal 1

      client['people'].find(name: 'Steve').first
      _(exporter.finished_spans.size).must_equal 2
    end
  end
end
