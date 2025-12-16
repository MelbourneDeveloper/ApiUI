import 'package:flutter/material.dart';
import 'package:flutter_app/src/models.dart';
import 'package:flutter_app/src/theme/chat_colors.dart';
import 'package:flutter_app/src/theme/theme_constants.dart';
import 'package:nimble_charts/flutter.dart' as charts;

/// Height for chart containers.
const _chartHeight = 250.0;

/// Builds a chart widget from ChartContent data.
Widget buildChart(ChartContent content, {required BuildContext context}) {
  final colors = Theme.of(context).extension<ChatColors>()!;

  return Container(
    height: _chartHeight,
    padding: const EdgeInsets.all(spacingSm),
    decoration: BoxDecoration(
      border: Border.all(color: colors.chartBorder),
      borderRadius: BorderRadius.circular(radiusSm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(content.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: spacingXs),
        Expanded(child: _buildChartContent(content, colors)),
      ],
    ),
  );
}

Widget _buildChartContent(ChartContent content, ChatColors colors) =>
    switch (content.chartType) {
      'bar' => _buildBarChart(content, colors),
      'line' => _buildLineChart(content, colors),
      'pie' => _buildPieChart(content, colors),
      _ => _buildBarChart(content, colors),
    };

Widget _buildBarChart(ChartContent content, ChatColors colors) {
  final data = _parseChartData(content.data);

  return charts.BarChart(
    [
      charts.Series<_ChartDataPoint, String>(
        id: content.title,
        colorFn: (_, _) => charts.ColorUtil.fromDartColor(colors.chartPrimary),
        domainFn: (point, _) => point.label,
        measureFn: (point, _) => point.value,
        data: data,
      ),
    ],
    animate: true,
    barRendererDecorator: charts.BarLabelDecorator<String>(),
    domainAxis: charts.OrdinalAxisSpec(
      renderSpec: charts.SmallTickRendererSpec(
        labelStyle: charts.TextStyleSpec(
          color: charts.ColorUtil.fromDartColor(colors.chartAxisLabel),
        ),
      ),
    ),
    primaryMeasureAxis: charts.NumericAxisSpec(
      renderSpec: charts.GridlineRendererSpec(
        labelStyle: charts.TextStyleSpec(
          color: charts.ColorUtil.fromDartColor(colors.chartAxisLabel),
        ),
      ),
    ),
  );
}

Widget _buildLineChart(ChartContent content, ChatColors colors) {
  final data = _parseChartData(content.data);

  return charts.LineChart(
    [
      charts.Series<_ChartDataPoint, num>(
        id: content.title,
        colorFn: (_, _) => charts.ColorUtil.fromDartColor(colors.chartPrimary),
        domainFn: (point, index) => index ?? 0,
        measureFn: (point, _) => point.value,
        data: data,
      ),
    ],
    animate: true,
    domainAxis: charts.NumericAxisSpec(
      renderSpec: charts.SmallTickRendererSpec(
        labelStyle: charts.TextStyleSpec(
          color: charts.ColorUtil.fromDartColor(colors.chartAxisLabel),
        ),
      ),
    ),
    primaryMeasureAxis: charts.NumericAxisSpec(
      renderSpec: charts.GridlineRendererSpec(
        labelStyle: charts.TextStyleSpec(
          color: charts.ColorUtil.fromDartColor(colors.chartAxisLabel),
        ),
      ),
    ),
  );
}

Widget _buildPieChart(ChartContent content, ChatColors colors) {
  final data = _parseChartData(content.data);
  final palette = _generatePalette(data.length, colors);

  return charts.PieChart<String>(
    [
      charts.Series<_ChartDataPoint, String>(
        id: content.title,
        colorFn: (_, index) => palette[index ?? 0],
        domainFn: (point, _) => point.label,
        measureFn: (point, _) => point.value,
        labelAccessorFn: (point, _) => point.label,
        data: data,
      ),
    ],
    animate: true,
    defaultRenderer: charts.ArcRendererConfig(
      arcRendererDecorators: [
        charts.ArcLabelDecorator(),
      ],
    ),
  );
}

List<_ChartDataPoint> _parseChartData(List<Map<String, dynamic>> data) => data
    .map(
      (item) => _ChartDataPoint(
        label: _extractLabel(item),
        value: _extractValue(item),
      ),
    )
    .toList();

String _extractLabel(Map<String, dynamic> item) {
  // Try explicit label keys first, then fall back to first string value
  final explicitKeys = ['label', 'x', 'name', 'country', 'category'];
  for (final key in explicitKeys) {
    if (item.containsKey(key)) return item[key].toString();
  }
  // Fall back to first string value
  for (final value in item.values) {
    if (value is String) return value;
  }
  return '';
}

double _extractValue(Map<String, dynamic> item) {
  // Try explicit value keys first, then fall back to first numeric value
  final explicitKeys = ['value', 'y', 'population', 'count', 'amount'];
  for (final key in explicitKeys) {
    if (item.containsKey(key)) return _parseNumeric(item[key]);
  }
  // Fall back to first numeric value
  for (final value in item.values) {
    if (value is num) return value.toDouble();
  }
  return 0;
}

double _parseNumeric(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? 0.0,
  _ => 0.0,
};

List<charts.Color> _generatePalette(int count, ChatColors colors) {
  final baseColors = [
    colors.chartPrimary,
    colors.chartSecondary,
    colors.chartTertiary,
    colors.accent,
  ];

  return List.generate(
    count,
    (i) => charts.ColorUtil.fromDartColor(baseColors[i % baseColors.length]),
  );
}

class _ChartDataPoint {
  const _ChartDataPoint({required this.label, required this.value});
  final String label;
  final double value;
}
