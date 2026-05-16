// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_aws_ses_suppression.dart';

const _tracerName = 'dartastic_otel_libs_aws_ses';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AwsSesResult {
  const AwsSesResult({
    this.messageId,
    this.region,
    this.recipientCount,
    this.bccCount,
    this.configurationSet,
    this.fromEmailIdentity,
    this.identityKind,
    this.sandbox,
    this.suppressionCheck,
    this.requestId,
    this.statusCode,
  });

  /// `MessageId` returned by SES.
  final String? messageId;

  /// `us-east-1` / `us-west-2` / `eu-west-1` etc.
  final String? region;

  /// Recipients in this send.
  final int? recipientCount;

  /// BCC count (SES applies the same per-message-cap, but BCC drives
  /// reputation differently).
  final int? bccCount;

  /// `ConfigurationSetName` used.
  final String? configurationSet;

  /// `FromEmailAddress` / `FromEmailAddressIdentityArn`.
  final String? fromEmailIdentity;

  /// `domain` / `email_address` / `idp` for the verified identity.
  final String? identityKind;

  /// True if the sending account is still in SES sandbox (cap=200/day).
  final bool? sandbox;

  /// Whether the recipient was on the account-level suppression list
  /// (causes silent drop unless explicitly disabled).
  final bool? suppressionCheck;

  /// `x-amzn-RequestId`.
  final String? requestId;

  final int? statusCode;
}

class AwsSesCallResult<T> {
  const AwsSesCallResult({required this.value, this.result});
  final T value;
  final AwsSesResult? result;
}

/// Wraps an Amazon SES v2 API call in a CLIENT span. [operation] is
/// one of `SendEmail`, `SendBulkEmail`, `SendCustomVerificationEmail`,
/// `SendRawEmail`, `CreateEmailTemplate`, `UpdateEmailTemplate`,
/// `DeleteEmailTemplate`, `TestRenderEmailTemplate`,
/// `CreateConfigurationSet`, `PutSuppressedDestination`,
/// `DeleteSuppressedDestination`, `ListSuppressedDestinations`,
/// `GetSendQuota`, `GetAccount`, `CreateEmailIdentity`,
/// `GetEmailIdentity`.
Future<T> tracedAwsSes<T>({
  required String operation,
  required Future<AwsSesCallResult<T>> Function() invoke,
  String? region,
}) async {
  if (awsSesInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'aws_ses',
    'rpc.method': operation,
    'aws_ses.operation': operation,
  };
  if (region != null) m['aws_ses.region'] = region;

  final span = _tracer().startSpan(
    'aws_ses $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.messageId != null) {
        extras.add(OTel.attributeString(
          'aws_ses.message.id',
          r.result!.messageId!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTel.attributeString(
          'aws_ses.region',
          r.result!.region!,
        ));
      }
      if (r.result!.recipientCount != null) {
        extras.add(OTel.attributeInt(
          'aws_ses.recipient_count',
          r.result!.recipientCount!,
        ));
      }
      if (r.result!.bccCount != null) {
        extras.add(OTel.attributeInt(
          'aws_ses.bcc_count',
          r.result!.bccCount!,
        ));
      }
      if (r.result!.configurationSet != null) {
        extras.add(OTel.attributeString(
          'aws_ses.configuration_set',
          r.result!.configurationSet!,
        ));
      }
      if (r.result!.fromEmailIdentity != null) {
        extras.add(OTel.attributeString(
          'aws_ses.from.identity',
          r.result!.fromEmailIdentity!,
        ));
      }
      if (r.result!.identityKind != null) {
        extras.add(OTel.attributeString(
          'aws_ses.identity.kind',
          r.result!.identityKind!,
        ));
      }
      if (r.result!.sandbox != null) {
        extras.add(OTel.attributeBool(
          'aws_ses.sandbox',
          r.result!.sandbox!,
        ));
      }
      if (r.result!.suppressionCheck != null) {
        extras.add(OTel.attributeBool(
          'aws_ses.suppression.matched',
          r.result!.suppressionCheck!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'aws_ses.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'SES HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
