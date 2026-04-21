// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webauthn.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WebauthnCredentialImpl _$$WebauthnCredentialImplFromJson(
  Map<String, dynamic> json,
) => _$WebauthnCredentialImpl(
  id: json['id'] as String,
  credentialId: json['credentialId'] as String,
  label: json['label'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
  transports:
      (json['transports'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  aaguid: json['aaguid'] as String?,
);

Map<String, dynamic> _$$WebauthnCredentialImplToJson(
  _$WebauthnCredentialImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'credentialId': instance.credentialId,
  'label': instance.label,
  'createdAt': instance.createdAt.toIso8601String(),
  'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
  'transports': instance.transports,
  'aaguid': instance.aaguid,
};

_$WebauthnRegistrationOptionsImpl _$$WebauthnRegistrationOptionsImplFromJson(
  Map<String, dynamic> json,
) => _$WebauthnRegistrationOptionsImpl(
  options: json['options'] as Map<String, dynamic>,
  pendingToken: json['pendingToken'] as String,
);

Map<String, dynamic> _$$WebauthnRegistrationOptionsImplToJson(
  _$WebauthnRegistrationOptionsImpl instance,
) => <String, dynamic>{
  'options': instance.options,
  'pendingToken': instance.pendingToken,
};

_$WebauthnAssertionOptionsImpl _$$WebauthnAssertionOptionsImplFromJson(
  Map<String, dynamic> json,
) => _$WebauthnAssertionOptionsImpl(
  options: json['options'] as Map<String, dynamic>,
  challengeToken: json['challengeToken'] as String,
);

Map<String, dynamic> _$$WebauthnAssertionOptionsImplToJson(
  _$WebauthnAssertionOptionsImpl instance,
) => <String, dynamic>{
  'options': instance.options,
  'challengeToken': instance.challengeToken,
};
