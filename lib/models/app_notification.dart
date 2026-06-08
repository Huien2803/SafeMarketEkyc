class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.icon = 'info',
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String icon;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      icon: icon,
    );
  }
}
