class TableModel {
  final String id;
  final String name;
  final int capacity;
  final String? createdAt;

  TableModel({
    required this.id,
    required this.name,
    required this.capacity,
    this.createdAt,
  });

  factory TableModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TableModel(
      id: id,
      name: data['name'] ?? 'Table',
      capacity: (data['capacity'] ?? 8) is int
          ? data['capacity'] ?? 8
          : int.tryParse(data['capacity'].toString()) ?? 8,
      createdAt: data['createdAt'],
    );
  }
}
