"""Create a local review gallery from real Flutter widget renders."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "dist" / "ui-review" / "gallery"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    expected = [f"{screen}-{theme}-{width}.png"
                for screen in ("home", "library", "series", "settings")
                for theme in ("dark", "light") for width in (1440, 390)]
    for name in expected:
        if not (OUTPUT / name).is_file():
            raise ValueError("Missing Flutter render: " + name)
    shutil.copyfile(ROOT / "docs/screenshots/resume-1280-flutter.png", OUTPUT / "before-home.png")
    (OUTPUT / "index.html").write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Zanzibarr — UI review</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#111518;color:#f0f2f4;font:16px/1.5 system-ui,sans-serif}
header,main{max-width:1500px;margin:auto;padding:24px}header{border-bottom:1px solid #36434d}
h1{font-size:28px;margin:0 0 8px}p{color:#b6c0c8;margin:8px 0}nav{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin-top:20px}
label{display:grid;gap:6px;font-size:14px}select,button{font:inherit;color:inherit;background:#252d34;border:1px solid #84939e;border-radius:10px;padding:10px 16px;min-height:48px}
button{cursor:pointer}button:focus-visible,select:focus-visible,a:focus-visible{outline:3px solid #ffb4a9;outline-offset:3px}a{color:#ffb4a9}
figure{margin:20px 0}img{width:100%;height:auto;display:block;border:1px solid #36434d;border-radius:12px}figure.narrow{max-width:390px;margin:20px auto}
figcaption{color:#b6c0c8;margin-bottom:12px}aside{background:#1b2126;border:1px solid #36434d;border-radius:12px;padding:20px;margin-top:24px}
ul{padding-left:22px}strong{color:#f0f2f4}small{color:#b6c0c8} .compare{display:grid;grid-template-columns:1fr 1fr;gap:20px}@media(max-width:800px){.compare{grid-template-columns:1fr}header,main{padding:16px}}
</style>
<header><h1>Zanzibarr · UI review</h1>
<p>Actual Flutter screens from the working code. Fictional sample titles, artwork and ratings. No accounts or playback are accessed.</p>
<nav aria-label="Preview controls">
<label>Screen<select id="screen"><option value="home">Home</option><option value="library">Library</option><option value="series">Series details</option><option value="settings">Settings</option></select></label>
<label>Theme<select id="theme"><option>dark</option><option>light</option></select></label>
<label>Layout<select id="width"><option value="1440">Desktop · 1440 px</option><option value="390">Narrow · 390 px</option></select></label>
<button id="compare" type="button" aria-pressed="false">Compare Home before / after</button>
</nav></header>
<main><p id="caption" role="status"></p><div id="views"><figure id="current"><figcaption>Current working UI · sample data</figcaption><a id="full" target="_blank" rel="noopener"><img id="render" alt=""></a></figure></div>
<aside><strong>What to review</strong><ul>
<li>A calmer neutral palette, stronger headings and consistent controls, menus, dialogs and focus outlines.</li>
<li>Persistent branding, labelled Library and Playlists shortcuts on wide windows, and quieter secondary actions.</li>
<li>Settings grouped by viewing, playback services, optional connections, and privacy.</li>
<li>Confirmed title names in history while preserving the original release identity and playhead.</li></ul>
<p>These are rendered views, not a browser port of the player. Narrow screenshots show the first viewport; the app screens scroll. Series data loading was fixed during review. No release bump or installer has been created.</p>
<p>Original direction: your Figma Minimalist layout and Cinematic surfaces. Further device, screen-reader and playback checks remain separate.</p></aside>
</main><script>
const screen=document.querySelector('#screen'),theme=document.querySelector('#theme'),width=document.querySelector('#width'),render=document.querySelector('#render'),full=document.querySelector('#full'),views=document.querySelector('#views'),current=document.querySelector('#current');
let comparing=false;function update(){const file=`${screen.value}-${theme.value}-${width.value}.png`;render.src=file;full.href=file;render.alt=`Zanzibarr ${screen.selectedOptions[0].text}, ${theme.value} theme, ${width.selectedOptions[0].text}, actual Flutter render`;current.className=width.value==='390'?'narrow':'';document.querySelector('#caption').textContent='Open a render for its full resolution. All review data is fictional.';}
for(const input of [screen,theme,width])input.addEventListener('change',()=>{comparing=false;document.querySelector('#before')?.remove();views.className='';document.querySelector('#compare').setAttribute('aria-pressed','false');update()});
document.querySelector('#compare').onclick=()=>{comparing=!comparing;document.querySelector('#compare').setAttribute('aria-pressed',String(comparing));document.querySelector('#before')?.remove();views.className=comparing?'compare':'';if(comparing){screen.value='home';theme.value='dark';width.value='1440';const before=document.createElement('figure');before.id='before';before.innerHTML='<figcaption>Earlier UI · prior fixture and viewport</figcaption><img src="before-home.png" alt="Earlier Zanzibarr Home render">';views.prepend(before)}update()};update();
</script></html>''', encoding="utf-8")
    print(OUTPUT / "index.html")


if __name__ == "__main__":
    main()
