import math
CSS = """:root{--g:#355E3B;--gd:#1B2F20;--c:#FFFDD0;--c2:#F2EDB7;--w:#fff}*{box-sizing:border-box;margin:0}
body{font-family:Roboto,system-ui,sans-serif;background:var(--c);color:var(--gd);line-height:1.65}
nav{background:var(--g);color:#fff}nav .wrap{display:flex;justify-content:space-between;align-items:center;height:60px}
nav a{color:#fff;text-decoration:none}.wrap{max-width:760px;margin:0 auto;padding:0 20px}
main{padding:36px 0 20px}h1{font-size:clamp(28px,6vw,40px);line-height:1.15;color:var(--g);margin-bottom:14px}
h2{color:var(--g);margin:28px 0 8px;font-size:24px}p,li{color:#33433a;margin-bottom:10px}ul{padding-left:22px}
table{border-collapse:collapse;width:100%;background:var(--w);border-radius:14px;overflow:hidden;margin:12px 0}
td,th{padding:10px 12px;text-align:left;border-bottom:1px solid var(--c2)}th{background:var(--g);color:#fff}
.box{background:var(--w);border-radius:20px;padding:20px;margin:14px 0;border:3px solid var(--gd)}
.btn{display:inline-block;background:var(--g);color:#fff;padding:12px 24px;border-radius:999px;text-decoration:none;font-weight:700;margin:10px 10px 0 0}
.links a{color:var(--g);font-weight:700;margin-right:14px}
footer{background:var(--g);color:#fff;padding:24px 0;margin-top:30px;font-size:14px}footer a{color:#fff;margin-right:14px}
input,select{font:inherit;font-size:18px;padding:10px;border-radius:12px;border:2px solid var(--c2);background:var(--c);width:100%}
label{font-weight:700;color:var(--g);font-size:13px;display:block;margin:8px 0 3px}
.res{margin-top:14px;border-radius:16px;padding:16px;background:var(--g);color:#fff}.res.low{background:#8a2a22}.res b{font-size:32px;display:block}"""

def page(slug, title, desc, body, extra=''):
    html = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} | AttendTrack</title>
<meta name="description" content="{desc}">
<link rel="canonical" href="https://attendtrack.online/{slug}">
<meta property="og:image" content="https://attendtrack.online/img/share.png"><link rel="icon" href="/favicon.ico" sizes="48x48"><link rel="icon" type="image/png" href="/icon-192.png" sizes="192x192">
<style>{CSS}</style></head><body>
<nav><div class="wrap"><a href="/" style="display:flex;align-items:center;gap:10px"><img src="/img/logo.png" alt="AttendTrack logo" width="34" height="34" style="border-radius:9px"><b>AttendTrack</b></a><a href="/app/"><b>Open app</b></a></div></nav>
<main class="wrap"><h1>{title}</h1>{body}
<div class="box"><b>Track it automatically.</b><p>AttendTrack counts every class and shows how many you can skip.</p><a class="btn" href="/app/">Open the web app</a><a class="btn" href="/#android">Get the Android app</a></div>
<p class="links"><a href="/75-percent-attendance-rule.html">75% rule</a><a href="/how-many-classes-can-i-skip.html">Classes you can skip</a><a href="/attendance-percentage-calculator.html">Calculator</a></p>
</main><footer><div class="wrap"><a href="/">Home</a><a href="/privacy.html">Privacy policy</a> © AttendTrack</div></footer>{extra}</body></html>"""
    open(f'site/{slug}', 'w', encoding='utf-8').write(html)

rows = ''.join(f'<tr><td>{a}</td><td>{t}</td><td>{a/t*100:.1f}%</td><td>{max(0, math.floor(a/0.75-t+1e-9))}</td></tr>'
               for a, t in [(30,36),(45,60),(60,80),(70,100),(22,36),(40,60)])
page('75-percent-attendance-rule.html', '75% Attendance Rule Explained',
     'What the 75% attendance rule means for college students, how it is calculated, and how to get back above 75% if you fall short.',
     """<p>Many colleges in India ask students to attend at least 75% of the classes held. Rules differ by college and university, so check your own handbook. This page explains the maths.</p>
<h2>The formula</h2><div class="box"><b>Attendance % = classes attended ÷ total classes held × 100</b></div>
<p>If you attended 30 of 36 classes, your attendance is 30 ÷ 36 × 100 = 83.3%.</p>
<h2>How many classes can you skip?</h2><p>The number of classes you can still miss and stay at 75% is: <b>attended ÷ 0.75 − total</b>, rounded down. With 30 attended out of 36, that is 40 − 36 = 4 classes.</p>
<h2>What if you are below 75%?</h2><p>You need to attend the next classes in a row. Attending n more classes in a row makes the new percentage (attended + n) ÷ (total + n). For 20 attended out of 36, you need 28 classes in a row to reach 75%.</p>
<h2>Examples</h2><table><tr><th>Attended</th><th>Total</th><th>Percent</th><th>Can skip</th></tr>"""+rows+"""</table>""")

page('how-many-classes-can-i-skip.html', 'How Many Classes Can I Skip?',
     'Work out how many classes you can skip and still keep 75% attendance. Simple formula with examples.',
     """<p>Use this to plan leave without dropping below your required attendance.</p>
<h2>Step by step</h2><ul><li>Write down classes attended (A) and total classes held (T).</li><li>Divide A by 0.75 (use 0.80 for an 80% rule).</li><li>Subtract T.</li><li>Round down. That is how many more classes you can miss.</li></ul>
<h2>Example</h2><p>A = 45, T = 60. 45 ÷ 0.75 = 60. 60 − 60 = 0. You are right at the limit and cannot skip the next class.</p>
<h2>Multi-hour classes</h2><p>A lab or a 3-hour class counts as 3 classes in AttendTrack, because each hour is held and counted. Check how your college counts them.</p>
<h2>Quick table (75% rule)</h2><table><tr><th>Attended</th><th>Total</th><th>Percent</th><th>Can skip</th></tr>"""+rows+"</table>")

calc = """<div class="box"><label for="att">Classes attended</label><input id="att" type="number" inputmode="numeric" min="0" value="30">
<label for="tot">Total classes held</label><input id="tot" type="number" inputmode="numeric" min="1" value="36">
<label for="tar">Required %</label><select id="tar"><option>65</option><option selected>75</option><option>80</option><option>85</option></select>
<div class="res" id="res" aria-live="polite"><b id="pct"></b><span id="msg"></span></div></div>"""
js = """<script>(function(){var a=document.getElementById('att'),b=document.getElementById('tot'),c=document.getElementById('tar'),r=document.getElementById('res'),p=document.getElementById('pct'),m=document.getElementById('msg');
function go(){var x=+a.value,y=+b.value,z=+c.value;if(!(y>0)||x<0||x>y){p.textContent='--';m.textContent='Attended must be between 0 and total.';r.className='res low';return}
var pc=x/y*100;p.textContent=(Math.round(pc*10)/10)+'%';
if(pc>=z){var s=Math.floor(x/(z/100)-y+1e-9);r.className='res';m.textContent=s>0?'You can skip '+s+' more class'+(s>1?'es':'')+' and stay at '+z+'%.':'You are at the limit. Do not skip the next class.'}
else{var n=Math.ceil((z*y-100*x)/(100-z)-1e-9);r.className='res low';m.textContent='Below '+z+'%. Attend the next '+n+' class'+(n>1?'es':'')+' in a row to get back.'}}
[a,b,c].forEach(function(e){e.addEventListener('input',go)});go()})();</script>"""
page('attendance-percentage-calculator.html', 'Attendance Percentage Calculator',
     'Free attendance percentage calculator. Enter classes attended and total classes to see your percentage and how many classes you can skip.',
     '<p>Type your numbers. The result updates as you type.</p>'+calc+'<h2>How it works</h2><p>Percentage = attended ÷ total × 100. Classes you can skip = attended ÷ (required % ÷ 100) − total, rounded down.</p>', js)
