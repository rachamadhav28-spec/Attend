import glob, os, re
for f in glob.glob(os.path.expanduser('~/.pub-cache/hosted/pub.dev/google_mobile_ads-*/android/build.gradle')):
    lines = open(f).read().split('\n')
    print('---', f)
    for i in range(52, min(len(lines), 64)):
        print(i + 1, lines[i])
    t = '\n'.join(lines)
    t = re.sub(r'configurations\.all\s*\{', 'configurations.configureEach {', t)
    t = re.sub(r'configurations\.all\b', 'configurations', t)
    t = re.sub(r'(configurations\s*\{[^}]*?)\ball\s*\{', r'\1configureEach {', t)
    open(f, 'w').write(t)
