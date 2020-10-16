# frozen_string_literal: true

# Copyright 2019 OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'

describe OpenTelemetry::Trace::Propagation::TraceContext::TextMapExtractor do
  let(:traceparent_key) { 'traceparent' }
  let(:tracestate_key) { 'tracestate' }
  let(:extractor) do
    OpenTelemetry::Trace::Propagation::TraceContext::TextMapExtractor.new(
      traceparent_key: traceparent_key,
      tracestate_key: tracestate_key
    )
  end
  let(:valid_traceparent_header) do
    '00-000000000000000000000000000000AA-00000000000000ea-01'
  end
  let(:invalid_traceparent_header) do
    'FF-000000000000000000000000000000AA-00000000000000ea-01'
  end
  let(:tracestate_header) { 'vendorname=opaquevalue' }
  let(:carrier) do
    {
      traceparent_key => valid_traceparent_header,
      tracestate_key => tracestate_header
    }
  end
  let(:context) { Context.empty }

  describe '#extract' do
    it 'yields the carrier and the header key' do
      yielded_keys = []
      extractor.extract(carrier, context) do |c, key|
        _(c).must_equal(carrier)
        yielded_keys << key
        c[key]
      end
      _(yielded_keys.sort).must_equal([traceparent_key, tracestate_key])
    end

    it 'returns a remote SpanReference with fields from the traceparent and tracestate headers' do
      ctx = extractor.extract(carrier, context) { |c, k| c[k] }
      span_reference = OpenTelemetry::Trace.current_span(ctx).reference
      _(span_reference).must_be :remote?
      _(span_reference.trace_id).must_equal(("\0" * 15 + "\xaa").b)
      _(span_reference.span_id).must_equal(("\0" * 7 + "\xea").b)
      _(span_reference.trace_flags).must_be :sampled?
      _(span_reference.tracestate).must_equal('vendorname=opaquevalue')
    end

    it 'uses a default getter if one is not provided' do
      ctx = extractor.extract(carrier, context)
      span_reference = OpenTelemetry::Trace.current_span(ctx).reference
      _(span_reference).must_be :remote?
      _(span_reference.trace_id).must_equal(("\0" * 15 + "\xaa").b)
      _(span_reference.span_id).must_equal(("\0" * 7 + "\xea").b)
      _(span_reference.trace_flags).must_be :sampled?
      _(span_reference.tracestate).must_equal('vendorname=opaquevalue')
    end

    it 'returns original context on error' do
      ctx = extractor.extract({}, context) { invalid_traceparent_header }
      _(ctx).must_equal(context)
    end
  end
end
