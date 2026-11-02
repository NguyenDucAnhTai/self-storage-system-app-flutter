class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.channels,
    required this.isRead,
    this.readAt,
    this.facilityId,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String recipientId;
  final String title;
  final String content;
  final String type;
  final String priority;
  final List<String> channels;
  final bool isRead;
  final DateTime? readAt;
  final String? facilityId;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    const requiredStrings = [
      'id',
      'recipientId',
      'title',
      'content',
      'type',
      'priority',
    ];
    if (requiredStrings.any((key) => json[key] is! String) ||
        json['isRead'] is! bool ||
        json['channels'] is! List ||
        (json['channels'] as List).any((channel) => channel is! String) ||
        (json['facilityId'] != null && json['facilityId'] is! String) ||
        (json['metadata'] != null && json['metadata'] is! Map)) {
      throw const FormatException('Invalid notification response.');
    }
    return AppNotification(
      id: json['id'] as String,
      recipientId: json['recipientId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String,
      channels: (json['channels'] as List).cast<String>(),
      isRead: json['isRead'] as bool,
      readAt: _date(json['readAt']),
      facilityId: json['facilityId'] as String?,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
    id: id,
    recipientId: recipientId,
    title: title,
    content: content,
    type: type,
    priority: priority,
    channels: channels,
    isRead: isRead ?? this.isRead,
    readAt: readAt ?? this.readAt,
    facilityId: facilityId,
    metadata: metadata,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value.toString());
}

class NotificationPagination {
  const NotificationPagination({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    const numberFields = ['page', 'limit', 'totalItems', 'totalPages'];
    const boolFields = ['hasNextPage', 'hasPrevPage'];
    if (numberFields.any((key) => json[key] is! num) ||
        (json['page'] is num && (json['page'] as num) < 1) ||
        (json['limit'] is num && (json['limit'] as num) < 1) ||
        (json['totalItems'] is num && (json['totalItems'] as num) < 0) ||
        (json['totalPages'] is num && (json['totalPages'] as num) < 0) ||
        boolFields.any((key) => json[key] is! bool)) {
      throw const FormatException('Invalid notification pagination response.');
    }
    return NotificationPagination(
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      totalItems: (json['totalItems'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      hasNextPage: json['hasNextPage'] as bool,
      hasPrevPage: json['hasPrevPage'] as bool,
    );
  }

  NotificationPagination decrementTotal() {
    final total = totalItems > 0 ? totalItems - 1 : 0;
    return NotificationPagination(
      page: page,
      limit: limit,
      totalItems: total,
      totalPages: total == 0 ? 0 : (total / limit).ceil(),
      hasNextPage: page < (total == 0 ? 0 : (total / limit).ceil()),
      hasPrevPage: page > 1,
    );
  }
}

class NotificationPage {
  const NotificationPage({required this.items, required this.pagination});
  final List<AppNotification> items;
  final NotificationPagination pagination;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawPagination = json['pagination'];
    if (rawItems is! List || rawPagination is! Map) {
      throw const FormatException('Invalid paginated notification response.');
    }
    final items = rawItems.map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid notification item.');
      }
      return AppNotification.fromJson(Map<String, dynamic>.from(value));
    }).toList();
    return NotificationPage(
      items: items,
      pagination: NotificationPagination.fromJson(
        Map<String, dynamic>.from(rawPagination),
      ),
    );
  }
}
