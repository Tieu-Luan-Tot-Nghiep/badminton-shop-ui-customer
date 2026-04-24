class CategoryEntity {
  const CategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
}
