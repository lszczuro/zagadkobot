import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/riddle.dart';

/// Ładuje zagadki z assets/riddles_db.json i umożliwia losowanie.
class RiddleRepository {
  List<Riddle>? _riddles;
  final _rng = Random();

  bool get isLoaded => _riddles != null;

  Future<void> load() async {
    final jsonStr = await rootBundle.loadString('riddles_db.json');
    final list = jsonDecode(jsonStr) as List<dynamic>;
    _riddles = list
        .map((e) => Riddle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Zwraca losową zagadkę. Wymaga wcześniejszego wywołania [load].
  Riddle random() {
    assert(isLoaded && _riddles!.isNotEmpty);
    return _riddles![_rng.nextInt(_riddles!.length)].shuffled(_rng);
  }

  /// Zwraca losową zagadkę inną niż [exclude].
  Riddle randomExcluding(String excludeId) {
    assert(isLoaded && _riddles!.isNotEmpty);
    final candidates = _riddles!.where((r) => r.id != excludeId).toList();
    if (candidates.isEmpty) return _riddles![_rng.nextInt(_riddles!.length)].shuffled(_rng);
    return candidates[_rng.nextInt(candidates.length)].shuffled(_rng);
  }
}
