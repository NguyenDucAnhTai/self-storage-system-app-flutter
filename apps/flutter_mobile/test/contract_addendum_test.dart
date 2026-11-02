import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/features/contracts/data/contract_repository.dart';

void main() {
  test(
    'renewal, signature and cancellation use the addendum API contract',
    () async {
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              calls.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {'id': 'c1', 'addendums': []},
                  },
                ),
              );
            },
          ),
        );
      final repo = ContractRepository(dio);
      expect(
        (await repo.renew('c1', DateTime.utc(2028), note: 'hello'))['id'],
        'c1',
      );
      await repo.signAddendum('c1', 'a1');
      await repo.cancelAddendum('c1', 'a1', 'changed plans');
      expect(calls[0].path, '/contracts/c1/addendums');
      expect(calls[0].data, {
        'type': 'renew',
        'newEndDate': '2028-01-01T00:00:00.000Z',
        'notes': 'hello',
      });
      expect(calls[1].path, '/contracts/c1/addendums/a1/customer-sign');
      expect(calls[1].data, {'termsAccepted': true});
      expect(calls[2].path, '/contracts/c1/addendums/a1/cancel');
      expect(calls[2].data, {'cancellationReason': 'changed plans'});
    },
  );
}
