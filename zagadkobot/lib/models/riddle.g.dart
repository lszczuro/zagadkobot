// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'riddle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Riddle _$RiddleFromJson(Map<String, dynamic> json) => Riddle(
  text: json['text'] as String,
  options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
  correctIndex: (json['correctIndex'] as num).toInt(),
  topic: $enumDecode(_$TopicEnumMap, json['topic']),
);

Map<String, dynamic> _$RiddleToJson(Riddle instance) => <String, dynamic>{
  'text': instance.text,
  'options': instance.options,
  'correctIndex': instance.correctIndex,
  'topic': _$TopicEnumMap[instance.topic]!,
};

const _$TopicEnumMap = {
  Topic.animals: 'animals',
  Topic.plants: 'plants',
  Topic.space: 'space',
  Topic.vehicles: 'vehicles',
};
