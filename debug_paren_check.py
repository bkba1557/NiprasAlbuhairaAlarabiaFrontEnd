from pathlib import Path
path = Path('lib/screens/order_management/supplier_portal_screen.dart')
text = path.read_text(encoding='utf-8')
lines = text.splitlines()
count = 0
for i in range(1222, 1340):
    line = lines[i-1]
    for ch in line:
        if ch == '(':
            count += 1
        elif ch == ')':
            count -= 1
    print(f'{i:4} {count:3} {line}')
print('final count:', count)
