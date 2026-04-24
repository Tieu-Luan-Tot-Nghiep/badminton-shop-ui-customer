import '../../domain/entities/category_entity.dart';

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconUrl;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: '${json['id'] ?? json['categoryId'] ?? ''}',
      name: '${json['name'] ?? json['categoryName'] ?? 'Unknown'}',
      slug: '${json['slug'] ?? json['name'] ?? ''}',
      iconUrl: json['iconUrl']?.toString() ?? json['imageUrl']?.toString(),
    );
  }

  factory CategoryModel.fromCache(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown',
      slug: map['slug']?.toString() ?? '',
      iconUrl: map['icon_url']?.toString(),
    );
  }

  Map<String, dynamic> toCache() {
    return {'id': id, 'name': name, 'slug': slug, 'icon_url': iconUrl};
  }

  CategoryEntity toEntity() {
    return CategoryEntity(id: id, name: name, slug: slug, iconUrl: iconUrl);
  }
}
