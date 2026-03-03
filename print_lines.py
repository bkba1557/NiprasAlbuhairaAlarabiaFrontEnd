path='lib/screens/stations_mangaments/close_session_screen.dart'
with open(path,'r',encoding='utf-8') as f:
    lines=f.readlines()
for i in range(3280,3320):
    print(f"{i+1}: {lines[i].rstrip()}")
