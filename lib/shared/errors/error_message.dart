import 'dart:async';

String errorMessage(Object e) => e is TimeoutException
    ? '처리 시간이 초과되었습니다. 다시 시도하세요.'
    : e.toString().replaceFirst(
        RegExp(r'^(Bad state: |FormatException: |Exception: )'),
        '',
      );
