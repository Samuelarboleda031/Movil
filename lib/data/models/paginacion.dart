class Paginacion<T> {
  final List<T> items;
  final int totalCount;
  final int pageSize;
  final int currentPage;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;

  Paginacion({
    required this.items,
    required this.totalCount,
    required this.pageSize,
    required this.currentPage,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  factory Paginacion.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    var list = json['items'] as List;
    List<T> itemsList = list.map((i) => fromJsonT(i)).toList();

    return Paginacion<T>(
      items: itemsList,
      totalCount: json['totalCount'] ?? 0,
      pageSize: json['pageSize'] ?? 0,
      currentPage: json['currentPage'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasPreviousPage: json['hasPreviousPage'] ?? false,
      hasNextPage: json['hasNextPage'] ?? false,
    );
  }
}
