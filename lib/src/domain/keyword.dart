/// Normalized, reusable keyword (e.g. topic, entity) unique by [value] and [type].
class Keyword {
  const Keyword({
    required this.id,
    required this.value,
    required this.type,
    required this.globalFrequency,
    required this.createdAt,
  });

  final String id;
  final String value;
  final String type;
  final int globalFrequency;
  final DateTime createdAt;

  Keyword copyWith({
    String? id,
    String? value,
    String? type,
    int? globalFrequency,
    DateTime? createdAt,
  }) {
    return Keyword(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      globalFrequency: globalFrequency ?? this.globalFrequency,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
