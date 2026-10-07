# hypr-min ✦

یک ستاپ هایپرلند **خیلی سبک، زیبا و بی‌دردسر** برای CachyOS (و هر توزیع Arch-محور).
طراحی‌شده بر پایهٔ هایپرلند **0.56+ با کانفیگ Lua** (فرمت قدیمی hyprlang منسوخ شده؛
این ستاپ روی سینتکس آینده‌نگر نوشته شده تا آپدیت‌های rolling توزیع خرابش نکنند).

تم: **Graphite & Gold** — پس‌زمینه گرافیتی تیره، لهجه طلایی گرم. آرام، خلوت، مناسب کار طولانی.

* * *

## چرا این اجزا؟ (حداکثر سبکی، حداقل خرابی)

| جزء | نقش | چرا این؟ |
| --- | --- | --- |
| `hyprland` (Lua config) | کامپوزیتور | کانفیگ Lua = فرمت رسمی فعلی؛ پایدار در برابر آپدیت‌ها |
| `waybar` | نوار وضعیت | سبک‌ترین بارِ کامل با ماژول‌های hyprland (IPC، بدون پولینگ سنگین) |
| `fuzzel` | لانچر + منوها | چند مگابایت، بدون daemon؛ هم اپ‌لانچر هم dmenu (کلیپ‌بورد/پاور/نتورک/صدا/کلیدها) |
| `mako` | نوتیفیکیشن | سبک‌ترین دیمن wayland-native |
| `hyprpaper` | والپیپر | رسمی، IPC دار، بدون انیمیشن اضافه |
| `hyprlock` + `hypridle` | قفل + idle | رسمی؛ قفل فوری با رندر ساده (سبک روی GPU) |
| `hyprpolkitagent` | پنجرهٔ رمز admin | رسمی؛ بدون آن نصب نرم‌افزار گرافیکی گیر می‌کند |
| `hyprshutdown` | خروج تمیز | اپ‌ها را مؤدبانه می‌بندد (روش توصیه‌شدهٔ رسمی) |
| `kitty` | ترمینال | GPU-accelerated، تم رنگی هماهنگ با تم دسکتاپ |
| `cliphist` + `wl-clipboard` | تاریخچه کلیپ‌بورد | متن کپی‌شده گم نمی‌شود |
| `grim` + `slurp` | اسکرین‌شات | بدون ابزار اضافه؛ ذخیره + کپی خودکار |
| `nmcli` (NetworkManager) | شبکه | منوی نتورک با کیبورد به‌جای اپلت مقیم GTK |

هیچ پلاگینی، هیچ AUR‌ای، هیچ daemon اضافه‌ای. همهٔ پکیج‌ها از مخزن رسمی `extra`
(تست خودکار در `tests/check_packages.py`).

* * *

## مهندسی مصرف منابع (چه چیزی سبک‌تر شد)

شش قانونی که کل ستاپ بر اساسشان بسته شده — و تست `tests/lint_budget.py`
نگهبان همین‌هاست تا با هر تغییر، بودجهٔ منابع بزرگ نشود:

1. **هیچ پروسهٔ مقیمی که یک کیبایند جایگزینش می‌شود.**
   `nm-applet` از استارت خودکار حذف شد (یک اپ GTK مقیم، حدود ۴۰–۶۰ مگابایت RSS
   و یک wakeup به‌ازای هر رویداد شبکه). جایش `SUPER+N` منوی شبکه با `nmcli` آمد
   و ماژول network در نوار. کل پروسه‌های مقیم نشست: **۶ عدد**
   (`hyprpaper`, `waybar`, `mako`, `hypridle`, `hyprpolkitagent`, `wl-paste`).
2. **هر پروسهٔ مقیم با `pgrep -x` گارد شده** — کانفیگ ریلود یا نشست دوم،
   دیمن تکراری روی هم تلنبار نمی‌کند.
3. **جایی که رویداد هست، پولینگ ممنوع.** ماژول‌های `hyprland/*` در نوار با IPC
   رویدادمحورند؛ `backlight` با udev؛ `mpris` با D-Bus؛ `pulseaudio` با PipeWire.
   تنها خواندن‌های زمان‌دار: `cpu=5s`, `memory=10s`, `temperature=10s`,
   `network=15s`, `battery=60s`, `clock=60s` (روی مرز دقیقه هم‌تراز می‌شود،
   یعنی دقیق با یک بیدارشدن در دقیقه) و `custom/updates=3600s`.
   اسکرول روی صدا/نور با خودِ waybar انجام می‌شود (`scroll-step`)، نه با
   spawn کردن `wpctl`/`brightnessctl` به‌ازای هر دندانهٔ اسکرول.
4. **fork فقط وقتی لازم است.** اسکریپت‌ها فقط با فشار کلید اجرا می‌شوند و
   هیچ‌کدام حلقهٔ `sleep` ندارند؛ اعلان‌های حین کار (مثل تغییر لایه‌اوت) با
   `hl.timer` و دیسپچ داخلی هایپرلند انجام می‌شود، نه با پروسهٔ اضافه.
5. **GPU فقط جایی که ارزان است.** سایه خاموش، بلور فقط روی دو لایهٔ باریک
   (نوار + نوتیفیکیشن) با `passes=1` و `size=4`، `xray` روشن، بلورِ
   special workspace و پاپ‌آپ‌ها خاموش، ویدیوپلیرها `opaque` و بدون گردی
   (ارزان‌ترین سطح ممکن برای کامپوزیت)، و انیمیشنِ move/resize دستی خاموش.
6. **نوار به سخت‌افزار ماشین وصل می‌شود، نه به آرزو.** ماژول‌های `battery`،
   `backlight`، `temperature` و نشانگر چیدمان کیبورد فقط وقتی نصب می‌مانند که
   سخت‌افزار/کانفیگ مربوطه واقعاً وجود داشته باشد؛ وگرنه نصب‌کننده همان
   لحظه حذفشان می‌کند (JSON هم معتبر می‌ماند).

ضمناً `kitty` با scrollback کوچک‌تر (۴۰۰۰ خط) و `sync_to_monitor` تنظیم شده،
`hyprlock` بدون بافت اضافه (یک shape طلایی = یک quad)، و منوی کلیدها
(`SUPER+/`) مستقیم از `hyprctl binds -j` خوانده می‌شود: هیچ فایل کشی
که قدیمی شود، هیچ daemon‌ای که نگه دارد.

* * *

## نصب

```
# ۱) کپی کردن پوشهٔ hypr-min روی سیستم (مثلاً با git یا فلش)
cd hypr-min
./install.sh            # نصب کامل
# یا:
./install.sh --dry-run        # فقط نمایش کارها، بدون تغییر
./install.sh --no-packages    # فقط کانفیگ‌ها (پکیج‌ها خودتان)
```

اسکریپت:

- پکیج‌های نصب‌نشده را با `pacman --needed` نصب می‌کند (نصب‌شده‌ها دست نمی‌خورند)؛
- کانفیگ‌های قبلی شما را با پسوند `.backup-تاریخ` نگه می‌دارد؛
- مسیر والپیپر را در `hyprpaper.conf` جای‌گذاری می‌کند؛
- ماژول‌های بی‌ربط به سخت‌افزار شما را از نوار حذف می‌کند
  (باتری/نور پس‌زمینه/سنسور دما/چیدمان دوم کیبورد)؛
- **`user.lua` شما را در آپدیت‌های بعدی حفظ می‌کند**؛
- در پایان خلاصهٔ کلیدها را چاپ می‌کند.

بعد: **لاگ‌اوت کنید و در SDDM نشست «Hyprland» را انتخاب کنید.**
(اولین اجرا ممکن است پنجرهٔ خوش‌آمد رسمی هایپرلند را نشان دهد؛ یک‌بار ببندیدش.)

* * *

## کلیدها

> کامل‌ترین مرجع، منوی زندهٔ خودِ ستاپ است: **`SUPER+/`** — همان لحظه از
> `hyprctl binds -j` خوانده می‌شود، پس هیچ‌وقت از کانفیگ عقب نمی‌ماند.
> متن انگلیسی هر ردیف، همان `description` داخل کانفیگ است.

### روزمره

| کلید | کار (description) |
| --- | --- |
| `SUPER+Return` | Terminal — ترمینال |
| `SUPER+D` / `SUPER+Space` | App launcher / App launcher (alt) — لانچر اپ‌ها |
| `SUPER+W` | Web browser — مرورگر (اولین مرورگر نصب‌شده) |
| `SUPER+E` | File manager — فایل‌منیجر (اولین مدیر فایل نصب‌شده) |
| `SUPER+Q` | Close window — بستن پنجره |
| `SUPER+SHIFT+Q` | Kill window — کشتن پنجره |
| `SUPER+1..0` | Workspace N — رفتن به ورک‌اسپیس |
| `SUPER+SHIFT+1..0` | Send window to workspace N — فرستادن پنجره |
| `SUPER+CTRL+1..0` | Send window to workspace N and follow — فرستادن و دنبال‌کردن |
| `SUPER+Arrow` / `SUPER+H J K` | Focus — فوکوس در جهت (چپ/پایین/بالا/راست) |
| `SUPER+SHIFT+Arrow` | Move window — جابه‌جایی پنجره (بین گروه‌ها هم کار می‌کند) |
| `SUPER+CTRL+Arrow` | Resize — تغییر اندازه (نگه‌داشتن = تکرار) |
| `ALT+Tab` | Cycle windows — چرخش پنجره‌ها |
| `SUPER+Tab` | Previous workspace — ورک‌اسپیس قبلی |
| `SUPER+SHIFT+Tab` | Focus urgent/last window — پرش به پنجرهٔ فوری/آخرین |
| `SUPER+mouse_down` / `mouse_up` | Next workspace (scroll) / Previous workspace (scroll) |
| سوایپ سه‌انگشتی ترک‌پد | تعویض ورک‌اسپیس (gesture) |
| سوایپ سه‌انگشتی به پایین | Scratchpad (gesture) |

### پنجره‌ها

| کلید | کار (description) |
| --- | --- |
| `SUPER+F` / `SUPER+SHIFT+F` | Fullscreen / Maximize |
| `SUPER+SHIFT+Space` | Toggle floating — شناور/کاشی |
| `SUPER+C` | Center floating window — وسط‌چین کردن شناور |
| `SUPER+SHIFT+P` | Pin window to all workspaces — پین روی همهٔ ورک‌اسپیس‌ها |
| `SUPER+P` | Pseudo-tiling (dwindle) — شبه‌کاشی (تمام‌قد) |
| `SUPER+\` / `SUPER+SHIFT+\` | Toggle split direction / Swap split halves |
| `SUPER+G` | Toggle group (tabs) — گروه/تب‌دار کردن |
| `SUPER+SHIFT+G` / `SUPER+CTRL+G` | Next tab in group / Previous tab in group |
| `SUPER+S` | Scratchpad — ورک‌اسپیس ویژه |
| `SUPER+SHIFT+S` | Send window to scratchpad |
| `SUPER+SHIFT+Return` | New scratchpad terminal — ترمینال تازه در اسکچ‌پد |
| `SUPER+mouse:272` / `mouse:273` | Drag window (mouse) / Resize window (mouse) |

### مانیتور چندگانه

| کلید | کار (description) |
| --- | --- |
| `SUPER+ALT+Arrow` | Focus monitor — فوکوس مانیتور همسایه |
| `SUPER+SHIFT+ALT+Arrow` | Move window to monitor |
| `SUPER+CTRL+ALT+Arrow` | Move workspace to monitor |

### منوها و کمک‌ها (همه on-demand، هیچ‌کدام مقیم نیستند)

| کلید | کار (description) |
| --- | --- |
| `SUPER+/` | Keybind cheat sheet — همین جدول، زنده و جستجوپذیر |
| `SUPER+T` | Tools menu (submap) — منوی ابزار (جدول پایین) |
| `SUPER+SHIFT+R` | Resize mode (submap) — حالت ریسایز دقیق |
| `SUPER+Escape` | Leave any submap — خروج از هر submap (همیشه فعال) |
| `SUPER+V` | Clipboard history — تاریخچهٔ کلیپ‌بورد |
| `SUPER+N` | Network menu — وای‌فای/اتصال‌ها بدون اپلت |
| `SUPER+A` | Audio output/input menu — انتخاب خروجی/ورودی صدا |
| `SUPER+I` | System info — CPU/RAM/دیسک/باتری/IP در یک اعلان |
| `SUPER+U` | Check for updates — شمارش آپدیت‌ها |
| `SUPER+SHIFT+U` | System update (terminal) — نصب آپدیت در ترمینال |
| `SUPER+X` | Power menu — قفل/خروج/خاموش/ری‌بوت/صفحهٔ خاموش |
| `SUPER+B` | Hide/show the bar — نوار را پنهان/پیدا کن |
| `SUPER+M` / `SUPER+,` / `SUPER+.` | Play/pause · Previous track · Next track |

### سیستم و نشست

| کلید | کار (description) |
| --- | --- |
| `SUPER+L` | Lock screen — قفل صفحه |
| `SUPER+R` | Reload config — ریلود کانفیگ |
| `SUPER+SHIFT+I` | Toggle idle + auto-lock — خاموش/روشن کردن قفل خودکار |
| `SUPER+SHIFT+O` | Screen off (DPMS) — خاموش کردن نمایشگر (با هر ورودی روشن می‌شود) |
| `SUPER+SHIFT+N` | Dismiss all notifications — پاک کردن همهٔ اعلان‌ها |

### اسکرین‌شات

| کلید | کار (description) |
| --- | --- |
| `Print` | Screenshot: full screen — ذخیره + کپی |
| `SHIFT+Print` | Screenshot: region — ناحیهٔ انتخابی |
| `ALT+Print` | Screenshot: active window — پنجرهٔ فعال |
| `SUPER+Print` | Screenshot: region to clipboard — فقط کلیپ‌بورد، بدون فایل |
| `SUPER+SHIFT+Print` | Screenshot: screen to clipboard — فقط کلیپ‌بورد |

### کلیدهای سخت‌افزاری (حتی روی صفحهٔ قفل؛ `SHIFT+` = گام ریز)

| کلید | کار (description) |
| --- | --- |
| `XF86AudioRaiseVolume` / `Lower` | Volume up / Volume down |
| `SHIFT+XF86AudioRaiseVolume` / `Lower` | Volume up (fine) / Volume down (fine) |
| `XF86AudioMute` / `XF86AudioMicMute` | Mute output / Mute microphone |
| `XF86MonBrightnessUp` / `Down` | Brightness up / Brightness down |
| `SHIFT+XF86MonBrightnessUp` / `Down` | Brightness up (fine) / Brightness down (fine) |
| `XF86AudioPlay` / `Pause` / `Stop` | Play/pause (media key) · Pause (media key) · Stop (media key) |
| `XF86AudioNext` / `Prev` | Next track (media key) / Previous track (media key) |
| `XF86Sleep` | Suspend (sleep key) |
| `XF86Explorer` / `XF86Search` | File manager (explorer key) / App launcher (search key) |

> نکته: کلید `L` عمداً فقط برای قفل است؛ فوکوس سمت‌راست با `SUPER+Right`.

### `SUPER+T` — منوی ابزار (یک کلید، بعد یک حرف)

| حرف | کار | | حرف | کار |
| --- | --- | --- | --- | --- |
| `t` | ترمینال | | `b` | مرورگر |
| `f` | فایل‌منیجر | | `e` | ادیتور متنی |
| `n` | منوی شبکه | | `a` | منوی صدا |
| `v` | کلیپ‌بورد | | `s` | اسکرین‌شات ناحیه |
| `i` | اطلاعات سیستم | | `p` | میکسر صدا |
| `k` | جدول کلیدها | | `u` | آپدیت سیستم |
| `l` | قفل صفحه | | `x` | منوی پاور |
| `m` | تعویض چیدمان (dwindle/master) | | `Esc`/`q`/`Enter` | خروج |

### `SUPER+SHIFT+R` — حالت ریسایز

`H J K L` یا جهت‌ها = ۶۰ پیکسل، `SHIFT+` همان‌ها = ۱۰ پیکسل (نگه‌داشتن = تکرار)،
`Esc`/`q`/`Enter` = خروج. اسم submap فعال در وسط نوار طلایی می‌شود.

* * *

## نوار وضعیت (چه چیزهایی اضافه شد)

طراحی همان «قرص‌های شناور» گرافیتی-طلایی است؛ فقط اطلاعات مفیدتر و خلوت‌تر:

| بخش | محتوا | هزینه |
| --- | --- | --- |
| چپ | ورک‌اسپیس‌ها + عنوان پنجره | IPC رویدادمحور |
| وسط | **حالت فعال (submap)** — فقط وقتی در `tools`/`resize` هستید | IPC، وگرنه پنهان |
| وسط | **پخش رسانه (mpris)** — عنوان/هنرمند، کلیک = play/pause، اسکرول = ترک بعد/قبل | D-Bus رویدادمحور، وگرنه پنهان |
| راست | **` CPU · 󰍛 RAM ·  دما`** در یک قرص؛ بالای آستانه طلایی/قرمز می‌شود | خواندن `/proc` و `/sys` |
| راست | tray اپ‌ها (اگر چیزی در آن باشد) | رویدادمحور |
| راست | **شبکه + صدا + نور پس‌زمینه** در یک قرص؛ راست‌کلیک = منوی شبکه/صدا، اسکرول = صدا/نور | netlink + PipeWire + udev |
| راست | **idle inhibitor** — کلیک = «خواب نرو» (برای ارائه/دانلود) | فقط وقتی فعال است دیده می‌شود |
| راست | باتری (درص + زمان باقی‌مانده در tooltip) | ۶۰ ثانیه |
| راست | **چیدمان کیبورد** (`us`/`ir`) — فقط اگر چند چیدمان فعال کرده باشید | IPC |
| راست | ساعت (کلیک = تاریخ، tooltip = تقویم) | هم‌تراز با مرز دقیقه |
| راست | **شمار آپدیت‌ها** — فقط وقتی آپدیتی هست؛ کلیک = نصب | یک بار در ساعت |
| راست | **`󰌌` جدول کلیدها** + **`⏻` منوی پاور** در یک قرص | on-demand |

هر ماژولی که حرفی برای گفتن ندارد **کاملاً پنهان** می‌شود (نه قرص خالی)،
پس نوار در حالت عادی همان خلوتی قبلی است.

پیش‌نمایش تصویری چیدمان: `docs/bar-mockup.svg` (سه حالت: خلوت، لپ‌تاپ شلوغ، submap فعال).

* * *

## رفتارهای «خودکار» (یعنی لازم نیست درگیرش شوید)

- **Idle:** بعد از ۵ دقیقه قفل، یک دقیقه بعد صفحه خاموش؛ با هر ورودی فوراً روشن.
  با `SUPER+SHIFT+I` موقتاً خاموش/روشن می‌شود (ارائه، دانلود طولانی، مطالعه).
  (Suspend خودکار عمداً **خاموش** است تا دانلود/بیلد شبانه نصفه نشود؛ در `hypridle.conf` کامنت شده.)
- **اسکرین‌شات:** هم ذخیره می‌شود در `~/Pictures/Screenshots` هم کپی به کلیپ‌بورد
  + نوتیفیکیشن با پیش‌نمایش خودِ تصویر.
- **Screen-share و فایل‌پیکر:** پورتال‌ها نصب و آماده‌اند (Discord/مرورگرها بدون تنظیم اضافه).
- **کلیپ‌بورد:** تاریخچهٔ متنی دائمی در طول نشست (بدون تاریخچهٔ تصویر: RAM/دیسک کمتر).
- **NVIDIA:** هیچ env دستی لازم نیست؛ درایورهای CachyOS کافی‌اند.
- **آپدیت هایپرلند:** کانفیگ Lua است، پس با آپدیت‌های rolling نمی‌شکند.
- **کلیدها با چیدمان فارسی:** چون `input.resolve_binds_by_sym = false` است،
  بایند‌ها همیشه روی چیدمان اول (`us`) کار می‌کنند.

* * *

## شخصی‌سازی (بدون ترس از آپدیت)

| فایل | برای |
| --- | --- |
| `~/.config/hypr/user.lua` | بایند/مانیتور/سوییچ‌های اضافه — **در آپدیت حفظ می‌شود** |
| `~/.config/hypr/hyprland.lua` | کل کانفیگ اصلی (کامنت‌دار) |
| `~/.config/hypr/scripts/*.sh` | منوها و کمک‌ها (هرکدام کوچک و مستقل) |
| `~/.config/waybar/{config,style.css}` | نوار وضعیت |
| `~/.config/fuzzel/fuzzel.ini`، `mako/config`، `kitty/kitty.conf` | لانچر/نوتیف/ترمینال |
| `~/.config/hypr/hyprlock.conf`، `hypridle.conf`، `hyprpaper.conf` | قفل/idle/والپیپر |

نمونه‌های آماده داخل `user.lua`: **کیبورد فارسی** (`us,ir` با `Alt+Shift`)،
بازگرداندن `nm-applet`، بایند مستقیم تعویض چیدمان، پیام‌های لایه‌اوت master،
قفل شدن با بستن درِ لپ‌تاپ، مانیتور اختصاصی، VRR، خاموش کردن بلور/انیمیشن،
و `render.new_render_scheduling` برای GPUهای ضعیف.

**هر بایندی که اضافه می‌کنید `description` بدهید** — خودبه‌خود در `SUPER+/` ظاهر می‌شود.

والپیپر خودتان: فایل `~/.config/hypr/assets/wallpaper.png` را عوض کنید (یا مسیر در `hyprpaper.conf`).

* * *

## تست‌ها

`tests/run_tests.sh` را اجرا کنید — ۱۰ آزمون، ۹۸ بررسی
(نیاز به `lua5.4`، `shellcheck`، `python3`، `jq` و `Pillow`):

1. آنالیز استاتیک شل (`bash -n` + `shellcheck`) روی همهٔ اسکریپت‌ها
2. اجرای واقعی کانفیگ Lua زیر یک API استاب (`hl.*`): بایند تکراری، فلگ غلط،
   API ناشناخته، **submap بدون راه خروج**، و **اجرای واقعی همهٔ callbackها**
   (تایپوی داخل lambda همین‌جا گیر می‌افتد، نه وقتی کلید را زدید)
3. اعتبارسنجی اسکیمای کانفیگ‌های hyprlang (lock/idle/paper) + سینتکس جدید dpms
   + نبودِ دیسپچر قدیمی در هیچ فایلی
4. اعتبارسنجی JSON/CSS وای‌بار (گروه‌ها، ماژول بلااستفاده، سلکتور CSS بی‌صاحب)
   + _ini_ فاززل + کانفیگ mako + **حداقل فاصلهٔ پولینگ**
5. بهداشت بایند/اسکریپت: هر `hl.bind` باید `description` داشته باشد، هر submap
   باید تعریف شده باشد، هر اسکریپتِ صدا‌شده باید وجود داشته باشد، و
   **README باید همهٔ بایند‌ها را مستند کرده باشد**
6. **بودجهٔ منابع:** سقف پروسه‌های مقیم، گارد `pgrep`، تعداد لایهٔ بلورشده،
   `passes`/`size` بلور، فاصلهٔ پولینگ نوار، نبودِ `sleep`/حلقهٔ بی‌پایان در اسکریپت‌ها
7. بررسی زندهٔ وجود همه پکیج‌ها در مخازن رسمی Arch
8. شبیه‌سازی سرتاسری نصب‌کننده (رومیزی + لپ‌تاپ + کیبورد دوچیدمانه +
   حفظ `user.lua` + dry-run) و معتبر ماندن JSON بعد از حذف ماژول‌ها
9. تست عملکردی اسکریپت‌ها با باینری‌های جعلی (nmcli/wpctl/pacman/hyprctl/…)
10. بهداشت repo (newline، CRLF، asset، cross-ref باینری‌ها)

نتیجهٔ آخرین اجرا: `tests/RESULTS.md`.

* * *

## عیب‌یابی سریع

| مشکل | راه |
| --- | --- |
| فونت‌ها مربع‌مربع‌اند | `sudo pacman -S inter-font ttf-jetbrains-mono-nerd noto-fonts` (نصب‌کننده خودش انجام می‌دهد) |
| بار نیامد | `waybar` را دستی در ترمینال اجرا کنید تا خطا را ببینید |
| نوار غیب شده | `SUPER+B` را زده‌اید؛ دوباره بزنید (یا `pkill -SIGUSR1 waybar`) |
| در یک حالت گیر کرده‌ام | `SUPER+Escape` از هر submap بیرون می‌آورد؛ اگر نشد: `hyprctl dispatch 'hl.dsp.submap("reset")'` |
| ماژول دما/باتری/نور نیست | نصب‌کننده تشخیص داده سخت‌افزارش را ندارید؛ `./install.sh` را دوباره اجرا کنید |
| نشانگر چیدمان `ir` ظاهر نمی‌شود | بعد از فعال‌کردن `kb_layout = "us,ir"` در `user.lua`، `./install.sh` را دوباره اجرا کنید |
| می‌خواهم به کانفیگ دست بزنم | فقط `user.lua`؛ بقیه با آپدیت بازنویسی می‌شوند |
| برگشت به کانفیگ قبلی | `mv ~/.config/hypr.backup-<تاریخ> ~/.config/hypr` |

ساخته‌شده با تحقیق کامل در ویکی رسمی هایپرلند (نسخهٔ اکتبر ۲۰۲۶) و تست خودکار. ✦
