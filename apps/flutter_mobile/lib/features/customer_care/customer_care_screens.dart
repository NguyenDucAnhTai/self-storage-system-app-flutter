import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import 'customer_care.dart';

const _green = Color(0xff006b5b);
const _categories = <String, String>{
  'billing_inquiry': 'Hỏi về thanh toán',
  'contract_inquiry': 'Hỏi về hợp đồng',
  'unit_change_request': 'Yêu cầu đổi kho',
  'inventory_move_request': 'Di chuyển hàng hóa',
  'access_pin_reset': 'Cấp lại mã truy cập',
  'service_complaint': 'Góp ý dịch vụ',
  'procedural_assistance': 'Hướng dẫn quy trình',
  'general_inquiry': 'Yêu cầu khác',
};
const _incidentCategories = <String, String>{
  'structural': 'Kết cấu',
  'electrical': 'Điện',
  'water_leak': 'Rò rỉ nước',
  'security': 'An ninh',
  'cleanliness': 'Vệ sinh',
  'other': 'Khác',
};
String _status(String value) =>
    const {
      'pending': 'Đang chờ tiếp nhận',
      'processing': 'Đang xử lý',
      'completed': 'Đã hoàn tất',
      'cancelled': 'Đã hủy',
      'reported': 'Đã báo cáo',
      'assigned': 'Đã phân công',
      'investigating': 'Đang xác minh',
      'in_progress': 'Đang xử lý',
      'resolved': 'Đã xử lý',
      'closed': 'Đã đóng',
      'low': 'Thấp',
      'medium': 'Trung bình',
      'high': 'Cao',
      'urgent': 'Khẩn cấp',
      'critical': 'Nghiêm trọng',
    }[value] ??
    'Đang cập nhật';
String _when(dynamic value) {
  final d = DateTime.tryParse('$value');
  return d == null
      ? 'Ngày chưa có'
      : '${d.toLocal().day.toString().padLeft(2, '0')}/${d.toLocal().month.toString().padLeft(2, '0')}/${d.toLocal().year}';
}

String _ref(dynamic value, String key) =>
    value is Map ? '${value[key] ?? ''}' : '';

class CareListScreen extends StatefulWidget {
  const CareListScreen({
    super.key,
    required this.repo,
    required this.incidents,
  });
  final CustomerCareRepository repo;
  final bool incidents;
  @override
  State<CareListScreen> createState() => _CareListScreenState();
}

class _CareListScreenState extends State<CareListScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  int _page = 1;
  bool _more = false;
  String get _path => widget.incidents ? '/incidents' : '/support-tickets';
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await widget.repo.list(_path, page: _page);
    _more = rows.length == 20;
    return rows;
  }

  Future<void> _refresh() async {
    _page = 1;
    _more = false;
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _loadMore(List<Map<String, dynamic>> current) async {
    final nextPage = _page + 1;
    try {
      final next = await widget.repo.list(_path, page: nextPage);
      if (!mounted) return;
      _page = nextPage;
      _more = next.length == 20;
      setState(() => _future = Future.value([...current, ...next]));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tải thêm được. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.incidents ? 'Báo cáo sự cố' : 'Hỗ trợ khách hàng'),
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      onPressed: () => context.push(
        widget.incidents ? '/incidents/create' : '/support/create',
      ),
      icon: const Icon(Icons.add),
      label: Text(widget.incidents ? 'Báo cáo sự cố' : 'Tạo yêu cầu'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được dữ liệu.'),
                TextButton(onPressed: _refresh, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        final rows = s.data!;
        if (rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Text(
                    widget.incidents
                        ? 'Bạn chưa có báo cáo sự cố.'
                        : 'Bạn chưa có yêu cầu hỗ trợ.',
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...rows.map(
                (row) => Card(
                  color: const Color(0xffe8f4f0),
                  child: ListTile(
                    title: Text(
                      '${row[widget.incidents ? 'incidentCode' : 'ticketCode'] ?? '—'} · ${row['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_status('${row['status']}')} · ${_when(row['createdAt'])}',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '${widget.incidents ? '/incidents' : '/support'}/${row['id']}',
                    ),
                  ),
                ),
              ),
              if (_more)
                TextButton(
                  onPressed: () => _loadMore(rows),
                  child: const Text('Tải thêm'),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class SupportCreateScreen extends StatefulWidget {
  const SupportCreateScreen({super.key, required this.repo});
  final CustomerCareRepository repo;
  @override
  State<SupportCreateScreen> createState() => _SupportCreateScreenState();
}

class _SupportCreateScreenState extends State<SupportCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = 'general_inquiry';
  bool _sending = false;
  bool _outcomeUnknown = false;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo yêu cầu hỗ trợ')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: _categories.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
            validator: (v) => v == null || v.trim().length < 3
                ? 'Nhập ít nhất 3 ký tự.'
                : null,
          ),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            decoration: const InputDecoration(labelText: 'Nội dung'),
            validator: (v) => v == null || v.trim().length < 5
                ? 'Nhập ít nhất 5 ký tự.'
                : null,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending || _outcomeUnknown ? null : _submit,
            child: _sending
                ? const CircularProgressIndicator()
                : const Text('Gửi yêu cầu'),
          ),
          if (_outcomeUnknown) ...[
            const Text(
              'Chưa thể xác nhận máy chủ đã nhận yêu cầu. Hãy kiểm tra danh sách trước khi gửi lại.',
            ),
            TextButton(
              onPressed: () => context.go('/support'),
              child: const Text('Mở danh sách yêu cầu'),
            ),
            TextButton(
              onPressed: () => setState(() => _outcomeUnknown = false),
              child: const Text('Tôi đã kiểm tra danh sách, cho phép gửi lại'),
            ),
          ],
        ],
      ),
    ),
  );
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final row = await widget.repo.createSupport({
        'category': _category,
        'priority': 'medium',
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'attachments': [],
      });
      if (mounted) context.go('/support/${row['id']}');
    } catch (error) {
      if (mounted) {
        final status = error is DioException
            ? error.response?.statusCode
            : null;
        if (status == null) setState(() => _outcomeUnknown = true);
        final message = status == 400
            ? 'Thông tin yêu cầu chưa hợp lệ. Vui lòng kiểm tra lại.'
            : status == 401
            ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
            : status == 403
            ? 'Tài khoản chưa được phép tạo yêu cầu hỗ trợ.'
            : status == 404
            ? 'Không tìm thấy thông tin liên quan đến yêu cầu.'
            : status == 409
            ? 'Trạng thái đã thay đổi. Hãy tải lại danh sách.'
            : status != null && status >= 500
            ? 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'
            : 'Chưa xác nhận được kết quả gửi. Tải lại danh sách trước khi gửi lại để tránh tạo trùng.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class CareDetailScreen extends StatefulWidget {
  const CareDetailScreen({
    super.key,
    required this.repo,
    required this.id,
    required this.incident,
  });
  final CustomerCareRepository repo;
  final String id;
  final bool incident;
  @override
  State<CareDetailScreen> createState() => _CareDetailScreenState();
}

class _CareDetailScreenState extends State<CareDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  String get _path => widget.incident ? '/incidents' : '/support-tickets';
  @override
  void initState() {
    super.initState();
    _future = widget.repo.detail(_path, widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.incident ? 'Chi tiết sự cố' : 'Chi tiết yêu cầu'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _future = widget.repo.detail(_path, widget.id),
              ),
              child: const Text('Không tải được. Thử lại'),
            ),
          );
        }
        final d = s.data!;
        final status = '${d['status'] ?? ''}';
        final label = widget.incident
            ? _incidentCategories['${d['category']}']
            : _categories['${d['category']}'];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: const Color(0xffe8f4f0),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d[widget.incident ? 'incidentCode' : 'ticketCode'] ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(_status(status)),
                    Text(_when(d['createdAt'])),
                  ],
                ),
              ),
            ),
            if (widget.incident) _IncidentTimeline(status: status),
            const SizedBox(height: 12),
            Text(
              label ?? 'Yêu cầu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${d['title'] ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${d['description'] ?? ''}'),
            if (d['facility'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cơ sở'),
                subtitle: Text(
                  _ref(d['facility'], 'name').isEmpty
                      ? 'Thông tin cơ sở'
                      : _ref(d['facility'], 'name'),
                ),
              ),
            if (d['contract'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hợp đồng'),
                subtitle: Text(_ref(d['contract'], 'contractCode')),
              ),
            if (widget.incident && d['storageUnit'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kho'),
                subtitle: Text(_ref(d['storageUnit'], 'unitNumber')),
              ),
            if (widget.incident &&
                d['images'] is List &&
                (d['images'] as List).isNotEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.image_outlined),
                title: Text('Có ảnh chứng cứ đính kèm'),
              ),
            if (!widget.incident && d['staffResponse'] is Map)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phản hồi từ nhân viên'),
                      const SizedBox(height: 8),
                      Text(
                        '${(d['staffResponse'] as Map)['responseMessage'] ?? ''}',
                      ),
                      Text(_when((d['staffResponse'] as Map)['respondedAt'])),
                    ],
                  ),
                ),
              ),
            if (widget.incident && d['investigationNotes'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cập nhật xử lý'),
                subtitle: Text('${d['investigationNotes']}'),
              ),
            if (widget.incident && d['resolution'] is Map)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kết quả xử lý'),
                subtitle: Text(
                  '${(d['resolution'] as Map)['resolutionNotes'] ?? ''}',
                ),
              ),
            if (!widget.incident && status == 'pending')
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _act(
                        'Hủy yêu cầu',
                        'Bạn có thể tạo yêu cầu mới sau này.',
                        () => widget.repo.cancelSupport(widget.id),
                      ),
                child: const Text('Hủy yêu cầu'),
              ),
            if (widget.incident && status == 'reported')
              FilledButton.tonal(
                onPressed: _busy ? null : _cancelIncident,
                child: const Text('Hủy báo cáo'),
              ),
            if (widget.incident && status == 'resolved')
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act(
                        'Đóng sự cố',
                        'Xác nhận đã xem kết quả xử lý.',
                        () => widget.repo.closeIncident(widget.id),
                      ),
                child: const Text('Đóng sự cố'),
              ),
          ],
        );
      },
    ),
  );
  Future<void> _cancelIncident() async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hủy báo cáo sự cố'),
        content: TextField(
          controller: reason,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Lý do hủy (ít nhất 5 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => context.pop(
              reason.text.trim().length >= 5 ? reason.text.trim() : null,
            ),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (value == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập lý do hủy gồm ít nhất 5 ký tự.')),
        );
      }
      return;
    }
    await _act(
      'Xác nhận hủy',
      'Báo cáo sẽ được hủy.',
      () => widget.repo.cancelIncident(widget.id, value),
    );
  }

  Future<void> _act(
    String title,
    String text,
    Future<void> Function() action,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        setState(() => _future = widget.repo.detail(_path, widget.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể xác nhận thao tác. Làm mới trạng thái trước khi thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class IncidentCreateBlockedScreen extends StatelessWidget {
  const IncidentCreateBlockedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Báo cáo sự cố')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_back_outlined, size: 48, color: _green),
          SizedBox(height: 16),
          Text(
            'Chưa thể gửi báo cáo sự cố',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Máy chủ yêu cầu ít nhất một ảnh chứng cứ dạng URL. Ứng dụng hiện chưa có luồng tải ảnh được xác minh về định dạng, giới hạn dung lượng và quyền truy cập an toàn. Bạn vẫn có thể xem và quản lý các báo cáo đã gửi.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _IncidentTimeline extends StatelessWidget {
  const _IncidentTimeline({required this.status});
  final String status;
  static const _steps = [
    'reported',
    'assigned',
    'investigating',
    'in_progress',
    'resolved',
    'closed',
  ];

  @override
  Widget build(BuildContext context) {
    final reached = _steps.indexOf(status);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiến trình xử lý',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _steps.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i <= reached
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: i <= reached ? _green : Colors.grey,
                ),
                title: Text(_status(_steps[i])),
              ),
            if (status == 'cancelled')
              const ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cancel_outlined, color: Colors.red),
                title: Text('Đã hủy'),
              ),
            const Text(
              'Các bước thể hiện trạng thái hiện tại từ máy chủ; thời điểm từng bước chỉ hiển thị khi API cung cấp.',
            ),
          ],
        ),
      ),
    );
  }
}
