import 'dart:math';
import '../models/reminder.dart';
import '../models/translation_models.dart';

/// Timing slot constants matching clinical shorthand used by the OCR API.
enum TimingSlot {
  beforeBreakfast('Before Breakfast', 7, 30),
  afterBreakfast ('After Breakfast',  8, 30),
  beforeLunch    ('Before Lunch',     12, 30),
  afterLunch     ('After Lunch',      13, 30),
  beforeDinner   ('Before Dinner',    19, 0),
  afterDinner    ('After Dinner',     20, 0),
  bedtime        ('Bedtime',          22, 0);

  const TimingSlot(this.label, this._h, this._m);
  final String label;
  final int    _h;
  final int    _m;
  (int, int) get defaultTime => (_h, _m);
}

/// Auto-generates [Reminder]s from OCR-extracted [MedicineInput]s.
class ReminderGenerator {
  static final _rng = Random();

  /// Maps frequency strings → number of doses per day.
  static int _timesPerDay(String frequency) {
    final f = frequency.trim().toLowerCase().replaceAll('.', '').replaceAll(' ', '');
    switch (f) {
      case 'od': case 'qd': case 'oncedaily': case 'once': return 1;
      case 'bd': case 'bid': case 'twicedaily': case 'twice': return 2;
      case 'tds': case 'tid': case 'thricedaily': case 'thrice': return 3;
      case 'qid': case 'fourtimesdaily': return 4;
    }
    if (f.contains('4') || f.contains('four')) return 4;
    if (f.contains('3') || f.contains('three') || f.contains('thrice')) return 3;
    if (f.contains('2') || f.contains('two') || f.contains('twice')) return 2;
    return 1;
  }

  static TimingSlot? _parseTimingSlot(String timing) {
    final t = timing.trim().toLowerCase().replaceAll('.', '').replaceAll(' ', '');
    if (t.isEmpty || t == 'notspecified') return null;
    if (t.contains('beforebreakfast') || t == 'bf' || t == 'ac') return TimingSlot.beforeBreakfast;
    if (t.contains('afterbreakfast')  || t == 'af' || t == 'pc') return TimingSlot.afterBreakfast;
    if (t.contains('beforelunch'))   return TimingSlot.beforeLunch;
    if (t.contains('afterlunch'))    return TimingSlot.afterLunch;
    if (t.contains('beforedinner'))  return TimingSlot.beforeDinner;
    if (t.contains('afterdinner'))   return TimingSlot.afterDinner;
    if (t.contains('bed') || t == 'hs') return TimingSlot.bedtime;
    if (t.contains('before')) return TimingSlot.beforeBreakfast;
    if (t.contains('after'))  return TimingSlot.afterBreakfast;
    return null;
  }

  static List<TimingSlot> _slotsFor(int times, TimingSlot? explicit) {
    if (explicit != null) {
      // Spread before/after preference across correct number of meal slots.
      final isBefore = explicit == TimingSlot.beforeBreakfast ||
          explicit == TimingSlot.beforeLunch || explicit == TimingSlot.beforeDinner;
      final ladder = isBefore
          ? [TimingSlot.beforeBreakfast, TimingSlot.beforeLunch, TimingSlot.beforeDinner]
          : [TimingSlot.afterBreakfast,  TimingSlot.afterLunch,  TimingSlot.afterDinner];
      if (explicit == TimingSlot.bedtime) return [TimingSlot.bedtime];
      if (times <= ladder.length) return ladder.sublist(0, times);
      return [...ladder.sublist(0, 3), TimingSlot.bedtime];
    }
    switch (times) {
      case 1:  return [TimingSlot.afterBreakfast];
      case 2:  return [TimingSlot.afterBreakfast, TimingSlot.afterDinner];
      case 3:  return [TimingSlot.afterBreakfast, TimingSlot.afterLunch, TimingSlot.afterDinner];
      default: return [TimingSlot.afterBreakfast, TimingSlot.afterLunch, TimingSlot.afterDinner, TimingSlot.bedtime];
    }
  }

  /// Generate [Reminder]s for a list of [MedicineInput]s from the OCR.
  static List<Reminder> generateFromInputs(List<MedicineInput> medicines) {
    final reminders = <Reminder>[];
    for (final m in medicines) {
      final times    = _timesPerDay(m.frequency);
      final explicit = _parseTimingSlot(m.timing);
      final slots    = _slotsFor(times, explicit);

      for (final slot in slots) {
        final (hour, minute) = slot.defaultTime;
        reminders.add(Reminder(
          id:           '${m.name.replaceAll(' ', '_')}_${slot.name}_${_rng.nextInt(99999999)}',
          medicineId:   m.name,
          medicineName: m.name,
          dosageLabel:  m.frequency,
          timingLabel:  slot.label,
          hour:         hour,
          minute:       minute,
        ));
      }
    }
    return reminders;
  }
}
