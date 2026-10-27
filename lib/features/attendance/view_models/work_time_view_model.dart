import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:work_time/data/settings_store.dart';
import 'package:work_time/domain/work_entry.dart';
import 'package:work_time/domain/work_repository.dart';
import 'package:work_time/shared/errors/error_message.dart';

class WorkTimeViewModel extends ChangeNotifier {
  WorkTimeViewModel({
    required this.repository,
    required this.store,
    required this.settings,
    required this.month,
    required List<WorkEntry> entries,
    required this.title,
  }) {
    _records = {for (final e in entries) dateKey(e.date): e};
  }
  final WorkRepository repository;
  final SettingsStore store;
  WorkSettings settings;
  final String title;
  DateTime month;
  DateTime? selectedDate;
  WorkEntry? draft;
  Map<String, WorkEntry> _records = {};
  bool loading = false, saving = false, loaded = true;
  String error = '', editError = '';
  final Map<bool, String> _timeInputErrors = {};
  bool get hasTimeInputErrors => _timeInputErrors.isNotEmpty;
  String? timeInputError(bool clockIn) => _timeInputErrors[clockIn];

  void updateTimeInput(bool clockIn, String text) {
    if (!canEdit || draft == null) return;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    final hour = match == null ? null : int.tryParse(match[1]!);
    final minute = match == null ? null : int.tryParse(match[2]!);
    if (text.trim().isNotEmpty &&
        (hour == null || minute == null || hour > 23 || minute > 59)) {
      _timeInputErrors[clockIn] = '00:00~23:59 형식으로 입력하세요.';
      editError = '';
      _emit();
      return;
    }
    _timeInputErrors.remove(clockIn);
    final base = clockIn ? draft!.date : draft!.clockOut ?? draft!.date;
    final value = text.trim().isEmpty
        ? null
        : DateTime(base.year, base.month, base.day, hour!, minute!);
    updateDraft(
      clockIn
          ? draft!.copyWith(clockIn: value, clearIn: value == null)
          : draft!.copyWith(clockOut: value, clearOut: value == null),
    );
  }

  int _generation = 0;
  bool _disposed = false;
  List<DateTime> get dates => monthDates(month);
  WorkEntry? entry(DateTime date) => _records[dateKey(date)];
  MonthSummary get summary => MonthSummary(_records.values);
  bool externalBusy = false;
  bool get canEdit => loaded && !loading && !saving && !externalBusy;
  void setExternalBusy(bool value) {
    externalBusy = value;
    _emit();
  }

  bool get dirty =>
      hasTimeInputErrors ||
      draft != null &&
          jsonEncode(draft!.toRow()) !=
              jsonEncode(
                (entry(draft!.date) ??
                        WorkEntry(
                          date: draft!.date,
                          standardMinutes: settings.standardMinutes,
                        ))
                    .toRow(),
              );
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> changeMonth(DateTime value, {bool refresh = false}) async {
    if (saving || dirty) return;
    final generation = ++_generation;
    final next = DateTime(value.year, value.month);
    final same = monthKey(next) == monthKey(month);
    month = next;
    loading = true;
    loaded = false;
    error = '';
    if (!same || !refresh) _records = {};
    draft = null;
    selectedDate = null;
    _emit();
    try {
      final entries = await repository.loadMonth(next);
      if (generation != _generation || _disposed) return;
      _records = {for (final e in entries) dateKey(e.date): e};
      loaded = true;
    } catch (e) {
      if (generation == _generation) error = errorMessage(e);
    } finally {
      if (generation == _generation) {
        loading = false;
        _emit();
      }
    }
  }

  void select(DateTime date) {
    if (!canEdit || dirty) return;
    selectedDate = date;
    _timeInputErrors.clear();
    draft =
        entry(date) ??
        WorkEntry(date: date, standardMinutes: settings.standardMinutes);
    editError = '';
    _emit();
  }

  void updateDraft(WorkEntry entry) {
    if (saving) return;
    draft = entry;
    editError = '';
    _emit();
  }

  void discard() {
    if (saving) return;
    draft = null;
    _timeInputErrors.clear();
    editError = '';
    _emit();
  }

  Future<bool> save() async {
    final value = draft;
    if (value == null || !canEdit) return false;
    if (hasTimeInputErrors) {
      editError = '출퇴근 시간 형식을 확인하세요.';
      _emit();
      return false;
    }
    editError = value.validate() ?? '';
    if (editError.isNotEmpty) {
      _emit();
      return false;
    }

    saving = true;
    _emit();
    try {
      final previous = entry(value.date);
      if (value.isEmpty) {
        if (previous != null) await repository.delete(previous);
      } else {
        await repository.save(value, expectedRevision: previous?.revision);
      }
      final records = await repository.loadMonth(month);
      if (_disposed) return false;
      _records = {for (final e in records) dateKey(e.date): e};
      draft = null;
      return true;
    } catch (e) {
      editError = errorMessage(e);
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  Future<bool> deleteSelected() async {
    final original = draft == null ? null : entry(draft!.date);
    if (original == null || !canEdit) return false;
    saving = true;
    editError = '';
    _emit();
    try {
      await repository.delete(original);
      final records = await repository.loadMonth(month);
      if (_disposed) return false;
      _records = {for (final e in records) dateKey(e.date): e};
      draft = null;
      _timeInputErrors.clear();
      return true;
    } catch (e) {
      editError = errorMessage(e);
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
