from pathlib import Path

path = Path('lib/screens/station_marketing/marketing_dashboard_screen.dart')
text = path.read_text(encoding='utf-8')

if 'Widget _buildStatusDistribution' not in text:
    sig = '  Widget _buildDashboardTab'
    start = text.find(sig)
    if start == -1:
        raise SystemExit('Dashboard tab not found')
    brace = text.find('{', start)
    depth = 0
    end_idx = None
    for i in range(brace, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                end_idx = i
                break
    if end_idx is None:
        raise SystemExit('Could not find end of dashboard tab')

    helpers = """

  Widget _distributionPanel({
    required String title,
    required IconData icon,
    required Widget child,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                foregroundColor: AppColors.primaryBlue,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusDistribution(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text('لا توجد بيانات بعد',
          style: TextStyle(color: AppColors.mediumGray));
    }

    final total = stations.length.toDouble();
    final items = [
      _StatusEntry(
        label: 'تحت المراجعة',
        count: _statusCount(stations, StationMarketingStatus.pendingReview),
        color: AppColors.warningOrange,
        icon: Icons.rate_review,
      ),
      _StatusEntry(
        label: 'مؤجرة',
        count: _statusCount(stations, StationMarketingStatus.rented),
        color: Colors.teal,
        icon: Icons.assignment_ind,
      ),
      _StatusEntry(
        label: 'ملغية',
        count: _statusCount(stations, StationMarketingStatus.cancelled),
        color: AppColors.errorRed,
        icon: Icons.cancel,
      ),
      _StatusEntry(
        label: 'تحت الصيانة',
        count: _statusCount(stations, StationMarketingStatus.maintenance),
        color: Colors.deepOrange,
        icon: Icons.build_circle,
      ),
      _StatusEntry(
        label: 'تحت الدراسة',
        count: _statusCount(stations, StationMarketingStatus.study),
        color: Colors.indigo,
        icon: Icons.search,
      ),
    ];

    return Column(
      children: items.map((item) {
        final percent = total == 0 ? 0 : item.count / total;
        return _buildBarRow(
          label: item.label,
          value: _formatNumber(item.count),
          percent: percent,
          color: item.color,
          icon: item.icon,
        );
      }).toList(),
    );
  }

  Widget _buildCityDistribution(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text('لا توجد بيانات بعد',
          style: TextStyle(color: AppColors.mediumGray));
    }

    final counts = <String, int>{};
    for (final station in stations) {
      final city = station.city.trim().isEmpty ? 'غير محدد' : station.city;
      counts[city] = (counts[city] ?? 0) + 1;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = stations.length.toDouble();
    final top = entries.take(6).toList();

    return Column(
      children: top.map((entry) {
        final percent = total == 0 ? 0 : entry.value / total;
        return _buildBarRow(
          label: entry.key,
          value: _formatNumber(entry.value),
          percent: percent,
          color: AppColors.accentBlue,
          icon: Icons.location_city,
        );
      }).toList(),
    );
  }

  Widget _buildLitersDistribution(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text('لا توجد بيانات بعد',
          style: TextStyle(color: AppColors.mediumGray));
    }

    final liters = <_NamedValue>[];
    for (final station in stations) {
      liters.add(
        _NamedValue(
          label: station.name,
          value: _stationLiters(station),
        ),
      );
    }
    liters.sort((a, b) => b.value.compareTo(a.value));

    final top = liters.take(6).toList();
    final maxValue = top.isEmpty ? 0 : top.first.value;

    return Column(
      children: top.map((entry) {
        final percent = maxValue == 0 ? 0 : entry.value / maxValue;
        return _buildBarRow(
          label: entry.label,
          value: _formatNumber(entry.value),
          percent: percent,
          color: AppColors.successGreen,
          icon: Icons.local_fire_department,
        );
      }).toList(),
    );
  }

  Widget _buildBarRow({
    required String label,
    required String value,
    required double percent,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsTable(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text('لا توجد محطات بعد',
          style: TextStyle(color: AppColors.mediumGray));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              MaterialStateProperty.all(AppColors.backgroundGray),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('المحطة')),
            DataColumn(label: Text('المدينة')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('المضخات')),
            DataColumn(label: Text('اللترات')),
            DataColumn(label: Text('المستأجر')),
            DataColumn(label: Text('التقييم')),
          ],
          rows: [
            for (int i = 0; i < stations.length; i++)
              _buildStationRow(i + 1, stations[i]),
          ],
        ),
      ),
    );
  }

  DataRow _buildStationRow(int index, MarketingStation station) {
    final liters = _stationLiters(station);
    final rating = _ratingForStation(station);
    return DataRow(
      cells: [
        DataCell(Text(index.toString())),
        DataCell(Text(station.name)),
        DataCell(Text(station.city)),
        DataCell(_statusBadge(station.status)),
        DataCell(Text(station.pumps.length.toString())),
        DataCell(Text(_formatNumber(liters))),
        DataCell(Text(station.tenantName ?? 'بدون')),
        DataCell(
          Text(
            rating,
            style: TextStyle(color: _ratingColor(rating)),
          ),
        ),
      ],
    );
  }

  double _stationLiters(MarketingStation station) {
    return station.pumps.fold<double>(
      0,
      (total, pump) => total + pump.soldLiters,
    );
  }

  String _formatNumber(num value) {
    return NumberFormat.decimalPattern('ar').format(value);
  }
"""
    text = text[:end_idx + 1] + helpers + text[end_idx + 1:]

path.write_text(text, encoding='utf-8')
