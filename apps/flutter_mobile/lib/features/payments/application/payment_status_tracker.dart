import 'dart:async';

import '../data/models/payment.dart';
import '../data/repositories/payment_repository.dart';

/// Bounded sequential polling; callers should stop it when their screen is disposed.
class PaymentStatusTracker {
  PaymentStatusTracker(
    this._repository, {
    this.interval = const Duration(seconds: 5),
    this.maxAttempts = 120,
  });
  final PaymentRepository _repository;
  final Duration interval;
  final int maxAttempts;
  Timer? _timer;
  int _attempts = 0;
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Stream<PaymentPollEvent> watch(String paymentId) {
    stop();
    _attempts = 0;
    late StreamController<PaymentPollEvent> controller;
    controller = StreamController<PaymentPollEvent>(
      onListen: () async {
        Future<void> poll() async {
          if (controller.isClosed || _attempts >= maxAttempts) {
            return;
          }
          _attempts++;
          var terminal = false;
          try {
            final payment = await _repository.getById(paymentId);
            if (!controller.isClosed) controller.add(PaymentPollUpdate(payment));
            if (payment.isTerminal) {
              terminal = true;
              stop();
            }
          } catch (error, stack) {
            if (!controller.isClosed) controller.add(PaymentPollError(error, stack));
          }
          if (terminal && !controller.isClosed) {
            await controller.close();
            return;
          }
          if (!controller.isClosed && _attempts >= maxAttempts) {
            controller.add(
              PaymentPollTimeout(TimeoutException(
                'Payment status was not confirmed after $maxAttempts checks.',
              )),
            );
            await controller.close();
          }
        }

        Future<void> runScheduledPoll() async {
          await poll();
          if (controller.isClosed || _attempts >= maxAttempts) return;
          _timer = Timer(interval, runScheduledPoll);
        }
        await runScheduledPoll();
      },
      onCancel: stop,
    );
    return controller.stream;
  }
}

sealed class PaymentPollEvent {
  const PaymentPollEvent();
}

class PaymentPollUpdate extends PaymentPollEvent {
  const PaymentPollUpdate(this.payment);
  final Payment payment;
}

class PaymentPollError extends PaymentPollEvent {
  const PaymentPollError(this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;
}

class PaymentPollTimeout extends PaymentPollEvent {
  const PaymentPollTimeout(this.error);
  final TimeoutException error;
}
