/// Represents a single database schema migration.
///
/// - [name] is a stable identifier such as `001_init_core_schema`.
/// - [sql] contains the SQL to apply for this migration.
class Migration {
  final String name;
  final String sql;

  const Migration({
    required this.name,
    required this.sql,
  });
}

/// Returns a new list of [Migration]s sorted by their [name].
///
/// File-based migrations use zero-padded numeric prefixes in the name,
/// so lexicographical ordering matches chronological ordering.
List<Migration> sortMigrationsByName(Iterable<Migration> migrations) {
  final sorted = List<Migration>.from(migrations);
  sorted.sort((a, b) => a.name.compareTo(b.name));
  return sorted;
}

