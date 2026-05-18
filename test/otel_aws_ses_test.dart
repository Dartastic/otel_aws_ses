// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_aws_ses/otel_aws_ses.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_aws_ses-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('SendEmail records recipients + config set + sandbox', () async {
    await tracedAwsSes<String>(
      operation: 'SendEmail',
      region: 'us-east-1',
      invoke: () async => const AwsSesCallResult(
        value: 'ok',
        result: AwsSesResult(
          messageId: '01000000-aaaa',
          region: 'us-east-1',
          recipientCount: 3,
          bccCount: 1,
          configurationSet: 'transactional',
          fromEmailIdentity: 'noreply@example.com',
          identityKind: 'domain',
          sandbox: false,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('aws_ses SendEmail')!);
    expect(a['aws_ses.region'], 'us-east-1');
    expect(a['aws_ses.recipient_count'], 3);
    expect(a['aws_ses.configuration_set'], 'transactional');
    expect(a['aws_ses.identity.kind'], 'domain');
    expect(a['aws_ses.sandbox'], false);
  });

  test('suppression match recorded', () async {
    await tracedAwsSes<String>(
      operation: 'SendEmail',
      invoke: () async => const AwsSesCallResult(
        value: 'ok',
        result: AwsSesResult(suppressionCheck: true),
      ),
    );
    final a = attrsOf(spans.findSpanByName('aws_ses SendEmail')!);
    expect(a['aws_ses.suppression.matched'], true);
  });

  test('suppression skips spans', () async {
    await runWithoutAwsSesInstrumentationAsync(() async {
      await tracedAwsSes<String>(
        operation: 'GetSendQuota',
        invoke: () async => const AwsSesCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('aws_ses '), isEmpty);
  });
}
