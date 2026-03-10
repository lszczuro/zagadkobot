// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  volume: (json['volume'] as num).toDouble(),
  voiceId: json['voiceId'] as String,
  modelsDownloaded: json['modelsDownloaded'] as bool,
);

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'volume': instance.volume,
      'voiceId': instance.voiceId,
      'modelsDownloaded': instance.modelsDownloaded,
    };
