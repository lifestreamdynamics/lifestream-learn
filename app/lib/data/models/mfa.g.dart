// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mfa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MfaMethodsImpl _$$MfaMethodsImplFromJson(Map<String, dynamic> json) =>
    _$MfaMethodsImpl(
      totp: json['totp'] as bool,
      webauthnCount: (json['webauthnCount'] as num?)?.toInt() ?? 0,
      hasBackupCodes: json['hasBackupCodes'] as bool? ?? false,
      backupCodesRemaining:
          (json['backupCodesRemaining'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$MfaMethodsImplToJson(_$MfaMethodsImpl instance) =>
    <String, dynamic>{
      'totp': instance.totp,
      'webauthnCount': instance.webauthnCount,
      'hasBackupCodes': instance.hasBackupCodes,
      'backupCodesRemaining': instance.backupCodesRemaining,
    };

_$TotpEnrolmentStartImpl _$$TotpEnrolmentStartImplFromJson(
  Map<String, dynamic> json,
) => _$TotpEnrolmentStartImpl(
  secret: json['secret'] as String,
  qrDataUrl: json['qrDataUrl'] as String,
  otpauthUrl: json['otpauthUrl'] as String,
  pendingEnrolmentToken: json['pendingEnrolmentToken'] as String,
);

Map<String, dynamic> _$$TotpEnrolmentStartImplToJson(
  _$TotpEnrolmentStartImpl instance,
) => <String, dynamic>{
  'secret': instance.secret,
  'qrDataUrl': instance.qrDataUrl,
  'otpauthUrl': instance.otpauthUrl,
  'pendingEnrolmentToken': instance.pendingEnrolmentToken,
};

_$TotpBackupCodesResponseImpl _$$TotpBackupCodesResponseImplFromJson(
  Map<String, dynamic> json,
) => _$TotpBackupCodesResponseImpl(
  backupCodes: (json['backupCodes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$$TotpBackupCodesResponseImplToJson(
  _$TotpBackupCodesResponseImpl instance,
) => <String, dynamic>{'backupCodes': instance.backupCodes};
