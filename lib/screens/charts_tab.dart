import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';

class ChartsTab extends StatefulWidget {
  final List<SteamPurchase> purchases;

  const ChartsTab({super.key, required this.purchases});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final stats = SteamStatistics(widget.purchases);

    if (widget.purchases.isEmpty) {
      return const Center(child: Text('Noch keine Diagrammdaten vorhanden.'));
    }

    final years = stats.years;
    _selectedYear = _resolveSelectedYear(years, stats.currentDate.year);

    final selectedYear = _selectedYear!;
    final annualRows = stats.annualStatistics;
    final quarterRows = stats.quarterlyStatisticsForYear(selectedYear);
    final chartMetrics = [
      _ChartMetric(
        title: 'Ausgaben pro Jahr',
        points: annualRows.map((row) {
          return _ChartPoint(
            xLabel: row.year.toString(),
            value: row.spending,
            valueLabel: _formatCurrency(row.spending),
          );
        }).toList(),
      ),
      _ChartMetric(
        title: 'Ausgaben pro Quartal',
        points: quarterRows.map((row) {
          return _ChartPoint(
            xLabel: row.quarter.toString(),
            value: row.spending,
            valueLabel: _formatCurrency(row.spending),
          );
        }).toList(),
      ),
      _ChartMetric(
        title: 'Rabatt pro Jahr',
        percentScale: true,
        points: annualRows.map((row) {
          return _ChartPoint(
            xLabel: row.year.toString(),
            value: row.averageDiscount == null
                ? null
                : row.averageDiscount! * 100,
            valueLabel: _formatPercent(row.averageDiscount),
          );
        }).toList(),
      ),
      _ChartMetric(
        title: 'Rabatt pro Quartal',
        percentScale: true,
        points: quarterRows.map((row) {
          return _ChartPoint(
            xLabel: row.quarter.toString(),
            value: row.averageDiscount == null
                ? null
                : row.averageDiscount! * 100,
            valueLabel: _formatPercent(row.averageDiscount),
          );
        }).toList(),
      ),
      _ChartMetric(
        title: 'Gesamtausgaben',
        points: annualRows.map((row) {
          return _ChartPoint(
            xLabel: row.year.toString(),
            value: row.cumulativeSpending,
            valueLabel: _formatCurrency(row.cumulativeSpending),
          );
        }).toList(),
      ),
      _ChartMetric(
        title: 'Gesamtausgaben im gewählten Jahr',
        points: quarterRows.map((row) {
          return _ChartPoint(
            xLabel: row.quarter.toString(),
            value: row.cumulativeSpending,
            valueLabel: _formatCurrency(row.cumulativeSpending),
          );
        }).toList(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(0.0, constraints.maxWidth - 32);
        final columnCount = contentWidth >= 1000 ? 2 : 1;
        final chartWidth = columnCount == 2
            ? (contentWidth - 16) / 2
            : contentWidth;
        final chartHeight = columnCount == 2 ? 324.0 : 292.0;
        final yearPicker = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Jahr', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: selectedYear,
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedYear = value;
                });
              },
              items: years.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
            ),
          ],
        );
        final title = Text(
          'Diagramme',
          style: Theme.of(context).textTheme.headlineMedium,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (contentWidth < 420)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 8), yearPicker],
              )
            else
              Row(children: [title, const Spacer(), yearPicker]),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: chartMetrics.map((metric) {
                return SizedBox(
                  width: chartWidth,
                  height: chartHeight,
                  child: _ChartPanel(metric: metric),
                );
              }).toList(),
            ),
            const SizedBox(height: 88),
          ],
        );
      },
    );
  }

  int _resolveSelectedYear(List<int> years, int preferredYear) {
    final selectedYear = _selectedYear;

    if (selectedYear != null && years.contains(selectedYear)) {
      return selectedYear;
    }

    if (years.contains(preferredYear)) {
      return preferredYear;
    }

    return years.last;
  }

  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String? _formatPercent(double? value) {
    if (value == null) {
      return null;
    }

    return '${(value * 100).round()}%';
  }
}

class _ChartMetric {
  final String title;
  final List<_ChartPoint> points;
  final bool percentScale;

  const _ChartMetric({
    required this.title,
    required this.points,
    this.percentScale = false,
  });
}

class _ChartPoint {
  final String xLabel;
  final double? value;
  final String? valueLabel;

  const _ChartPoint({
    required this.xLabel,
    required this.value,
    required this.valueLabel,
  });
}

class _ChartPanel extends StatelessWidget {
  final _ChartMetric metric;

  const _ChartPanel({required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValues = metric.points.any((point) => point.value != null);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF5B9CD3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            Text(
              metric.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hasValues
                  ? CustomPaint(
                      painter: _LineChartPainter(
                        points: metric.points,
                        percentScale: metric.percentScale,
                      ),
                      child: const SizedBox.expand(),
                    )
                  : Center(
                      child: Text(
                        'Keine Daten',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final bool percentScale;

  const _LineChartPainter({required this.points, required this.percentScale});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final values = points.map((point) => point.value).whereType<double>();
    final maxValue = values.fold(0.0, math.max);
    final yMax = percentScale ? 100.0 : math.max(1.0, maxValue * 1.2);
    final chartRect = Rect.fromLTWH(
      20,
      18,
      math.max(1.0, size.width - 40),
      math.max(1.0, size.height - 56),
    );

    _drawGrid(canvas, chartRect);
    _drawTrendLine(canvas, chartRect, yMax);
    _drawValueLine(canvas, chartRect, yMax);
    _drawXAxisLabels(canvas, chartRect, size);
  }

  void _drawGrid(Canvas canvas, Rect chartRect) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..strokeWidth = 1.2;

    for (var index = 0; index <= 4; index++) {
      final y = chartRect.top + (chartRect.height / 4) * index;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    for (var index = 0; index < points.length; index++) {
      final x = _xForIndex(index, chartRect);
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
  }

  void _drawTrendLine(Canvas canvas, Rect chartRect, double yMax) {
    final knownPoints = <({int index, double value})>[];

    for (var index = 0; index < points.length; index++) {
      final value = points[index].value;

      if (value == null) {
        continue;
      }

      knownPoints.add((index: index, value: value));
    }

    if (knownPoints.length < 2) {
      return;
    }

    final regression = _linearRegression(knownPoints);
    final path = Path();

    for (var index = 0; index < points.length; index++) {
      final trendValue = (regression.slope * index + regression.intercept)
          .clamp(0.0, yMax)
          .toDouble();
      final point = Offset(
        _xForIndex(index, chartRect),
        _yForValue(trendValue, chartRect, yMax),
      );

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final trendPaint = Paint()
      ..color = const Color(0xFFCDE8FF).withValues(alpha: 0.82)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, trendPaint);
  }

  void _drawValueLine(Canvas canvas, Rect chartRect, double yMax) {
    final path = Path();
    final pointOffsets = <({int index, Offset offset})>[];
    var hasStartedPath = false;

    for (var index = 0; index < points.length; index++) {
      final value = points[index].value;

      if (value == null) {
        continue;
      }

      final offset = Offset(
        _xForIndex(index, chartRect),
        _yForValue(value, chartRect, yMax),
      );
      pointOffsets.add((index: index, offset: offset));

      if (!hasStartedPath) {
        path.moveTo(offset.dx, offset.dy);
        hasStartedPath = true;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF326C9E)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    for (final pointOffset in pointOffsets) {
      canvas.drawCircle(pointOffset.offset, 4.5, dotPaint);
      canvas.drawCircle(pointOffset.offset, 4.5, dotBorderPaint);
      _drawValueLabel(
        canvas,
        chartRect,
        pointOffset.offset,
        points[pointOffset.index].valueLabel,
        shouldDraw: _shouldDrawValueLabel(pointOffset.index),
      );
    }
  }

  void _drawValueLabel(
    Canvas canvas,
    Rect chartRect,
    Offset point,
    String? label, {
    required bool shouldDraw,
  }) {
    if (!shouldDraw || label == null) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      ellipsis: '...',
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 86);
    final labelSize = Size(textPainter.width + 10, textPainter.height + 6);
    var left = point.dx - labelSize.width / 2;
    left = left.clamp(chartRect.left, chartRect.right - labelSize.width);
    var top = point.dy - labelSize.height - 10;

    if (top < chartRect.top) {
      top = point.dy + 10;
    }

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, labelSize.width, labelSize.height),
      const Radius.circular(4),
    );

    canvas.drawRRect(labelRect, Paint()..color = const Color(0xCC111820));
    textPainter.paint(
      canvas,
      Offset(
        left + (labelSize.width - textPainter.width) / 2,
        top + (labelSize.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawXAxisLabels(Canvas canvas, Rect chartRect, Size size) {
    final interval = points.length <= 8 ? 1 : (points.length / 8).ceil();

    for (var index = 0; index < points.length; index++) {
      if (index != points.length - 1 && index % interval != 0) {
        continue;
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: points[index].xLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 58);
      final x = _xForIndex(index, chartRect);
      final labelOffset = Offset(
        (x - textPainter.width / 2).clamp(0.0, size.width - textPainter.width),
        chartRect.bottom + 14,
      );

      textPainter.paint(canvas, labelOffset);
    }
  }

  ({double slope, double intercept}) _linearRegression(
    List<({int index, double value})> points,
  ) {
    final count = points.length.toDouble();
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumXX = 0.0;

    for (final point in points) {
      final x = point.index.toDouble();
      final y = point.value;

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final denominator = count * sumXX - sumX * sumX;

    if (denominator.abs() < 0.0001) {
      return (slope: 0, intercept: sumY / count);
    }

    final slope = (count * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / count;

    return (slope: slope, intercept: intercept);
  }

  bool _shouldDrawValueLabel(int index) {
    if (points.length <= 10) {
      return true;
    }

    return index == 0 || index == points.length - 1 || index.isEven;
  }

  double _xForIndex(int index, Rect chartRect) {
    if (points.length == 1) {
      return chartRect.center.dx;
    }

    return chartRect.left + chartRect.width * index / (points.length - 1);
  }

  double _yForValue(double value, Rect chartRect, double yMax) {
    final fraction = (value / yMax).clamp(0.0, 1.0);

    return chartRect.bottom - chartRect.height * fraction;
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.percentScale != percentScale;
  }
}
