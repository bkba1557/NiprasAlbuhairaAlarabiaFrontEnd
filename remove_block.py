from pathlib import Path
path = Path('lib/screens/stations_mangaments/station_details_screen.dart')
lines = path.read_text(encoding='utf-8').splitlines()
start = next(i for i,line in enumerate(lines) if line.strip().startswith('Widget _buildPumpsTab('))
end = next(i for i,line in enumerate(lines) if line.strip().startswith('Widget _buildSessionsTab('))
del lines[start:end]
path.write_text('\n'.join(lines)+'\n', encoding='utf-8')
