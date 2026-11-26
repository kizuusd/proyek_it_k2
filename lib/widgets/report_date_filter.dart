import 'package:flutter/material.dart';

class ReportDateFilter extends StatelessWidget {
  const ReportDateFilter({
    super.key,
    required this.range,
    required this.onChanged,
  });

  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  static DateTime get today => DateUtils.dateOnly(DateTime.now());

  static DateTimeRange get lastSevenDays {
    final end = today;
    return DateTimeRange(
      start: DateTime(end.year, end.month, end.day - 6),
      end: end,
    );
  }

  static bool includes(String date, DateTimeRange? range) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return false;
    final day = DateUtils.dateOnly(parsed);
    return range == null
        ? DateUtils.isSameDay(day, today)
        : !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  @override
  Widget build(BuildContext context) {
    final currentDay = today;
    final week = lastSevenDays;
    final localizations = MaterialLocalizations.of(context);
    final selected = range ?? DateTimeRange(start: currentDay, end: currentDay);
    final startLabel = localizations.formatCompactDate(selected.start);
    final endLabel = localizations.formatCompactDate(selected.end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          startLabel == endLabel ? startLabel : '$startLabel – $endLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Hari Ini'),
              selected: range == null,
              onSelected: (_) => onChanged(null),
            ),
            ChoiceChip(
              label: const Text('7 Hari Terakhir'),
              selected: range == week,
              onSelected: (_) => onChanged(week),
            ),
            TextButton.icon(
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: const Text('Pilih Rentang Tanggal'),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: currentDay,
                  currentDate: currentDay,
                  initialDateRange: selected,
                  helpText: 'Pilih Rentang Tanggal',
                );
                if (picked != null && context.mounted) onChanged(picked);
              },
            ),
          ],
        ),
      ],
    );
  }
}
