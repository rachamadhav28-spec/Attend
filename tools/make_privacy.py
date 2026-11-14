import html
t = html.escape(open('PRIVACY_POLICY.md', encoding='utf-8').read())
page = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Privacy Policy - Attend Track</title></head>'
        '<body style="font-family:sans-serif;background:#FFFDD0;color:#1B2F20;max-width:760px;margin:0 auto;padding:24px">'
        '<p><a href="/">&larr; Attend Track</a></p>'
        '<pre style="white-space:pre-wrap;font-family:inherit;line-height:1.6">' + t + '</pre></body></html>')
open('_site/privacy.html', 'w', encoding='utf-8').write(page)
