<div align="center" dir="rtl">

<img src="docs/icon.png" width="128" alt="AppSweep">

# AppSweep

**برنامه‌ها را کامل حذف کنید. فضای دیسک را پس بگیرید.**

یک پاک‌کننده‌ی زیبا و بومی برای macOS — برنامه‌ها را همراه با تمام فایل‌های جامانده‌شان حذف کنید،
کش‌ها را پاک کنید و باقی‌مانده‌ی برنامه‌هایی را که قبلاً پاک کرده‌اید پیدا کنید.

[![دانلود برای مک](https://img.shields.io/badge/Download-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/AliRazaviDeveloper/AppSweep/releases/latest/download/AppSweep.dmg)
[![ویندوز — به‌زودی](https://img.shields.io/badge/Windows-Coming%20Soon-555555?style=for-the-badge&logo=windows&logoColor=white)](#پلتفرم‌ها)
[![لینوکس — به‌زودی](https://img.shields.io/badge/Linux-Coming%20Soon-555555?style=for-the-badge&logo=linux&logoColor=white)](#پلتفرم‌ها)

[English](README.md) · [فارسی](README.fa.md)

<br>

<img src="docs/screenshots/overview-fa.png" width="860" alt="AppSweep">

</div>

<div dir="rtl">

## ✨ امکانات

- 🗑 **حذف کامل برنامه‌ها** — وقتی برنامه را فقط به سطل زباله می‌کشید، گیگابایت‌ها فایل جا می‌ماند. AppSweep همه را پیدا می‌کند: Application Support، کش‌ها، تنظیمات، کانتینرها، لاگ‌ها، کوکی‌ها، Launch Agentها و… و خودتان انتخاب می‌کنید چه چیزی حذف شود.
- 🔄 **ریست برنامه** — برنامه بماند، فقط داده‌ها و تنظیماتش پاک شود.
- ✨ **پاک‌سازی کش** — کش برنامه‌ها، لاگ‌ها و فایل‌های اضافی توسعه‌دهنده (DerivedData در Xcode، کش شبیه‌ساز، npm، Gradle و…).
- 📦 **یافتن باقی‌مانده‌ها** — فایل‌هایی که از برنامه‌های حذف‌شده جا مانده‌اند.
- 📊 **داشبورد** — وضعیت دیسک، حجم برنامه‌ها و بزرگ‌ترین برنامه‌ها در یک نگاه.
- 🛡 **امن** — همه‌چیز به سطل زباله می‌رود و قابل برگشت است. برنامه‌های سیستمی macOS محافظت می‌شوند.
- 🖱 **کشیدن و رها کردن** — هر فایل ‎`.app`‎ را روی پنجره بکشید تا فوراً بررسی شود.
- 🌍 **فارسی و انگلیسی** — با چیدمان کامل راست‌به‌چپ.

## پلتفرم‌ها

| پلتفرم | وضعیت | دانلود |
|---|---|---|
| **macOS** نسخه‌ی ۱۴ به بعد (Apple Silicon و Intel) | ✅ موجود | [**AppSweep.dmg**](https://github.com/AliRazaviDeveloper/AppSweep/releases/latest/download/AppSweep.dmg) |
| **Windows** ۱۰ و ۱۱ | 🚧 به‌زودی | — |
| **Linux** | 🚧 به‌زودی | — |

> برای باخبر شدن از انتشار نسخه‌ی ویندوز و لینوکس، ریپازیتوری را ⭐ کنید یا از منوی **Watch → Custom → Releases** دنبالش کنید.

## 📥 نصب

### روش ۱ — نصب با یک دستور (پیشنهادی)

این دستور را در **Terminal** اجرا کنید:

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/AliRazaviDeveloper/AppSweep/main/install.sh | bash
```

<div dir="rtl">

آخرین نسخه دانلود و در **Applications** نصب و اجرا می‌شود — بدون هیچ پیغام امنیتی.

### روش ۲ — دانلود فایل DMG

۱. فایل **[AppSweep.dmg](https://github.com/AliRazaviDeveloper/AppSweep/releases/latest/download/AppSweep.dmg)** را دانلود کنید.<br>
۲. بازش کنید و **AppSweep** را داخل پوشه‌ی **Applications** بکشید.<br>
۳. این دستور را یک بار در ترمینال اجرا کنید و بعد برنامه را باز کنید:

</div>

```bash
xattr -dr com.apple.quarantine /Applications/AppSweep.app
```

<div dir="rtl">

> چرا مرحله‌ی ۳ لازم است؟ AppSweep هنوز توسط اپل notarize نشده، برای همین وقتی از مرورگر دانلود شود macOS پیغام «Apple could not verify…» می‌دهد و گزینه‌ی **Move to Trash** را نشان می‌دهد. برنامه امن است و این دستور فقط علامت قرنطینه‌ی دانلود را برمی‌دارد. راه دیگر: روی **Done** بزنید، سپس در **System Settings ← Privacy & Security** روی **Open Anyway** کلیک کنید. روش ۱ اصلاً این مشکل را ندارد.

**پیشنهاد:** برای اسکن کامل، در **System Settings ← Privacy & Security ← Full Disk Access** به AppSweep دسترسی بدهید.

## 🔒 حریم خصوصی

AppSweep کاملاً روی مک شما اجرا می‌شود؛ **هیچ ارتباط اینترنتی، آمارگیری یا حساب کاربری ندارد** و هیچ اطلاعاتی از کامپیوتر شما خارج نمی‌شود.

## 📄 مجوز

منتشرشده تحت [مجوز MIT](LICENSE). © ۲۰۲۶ علی رضوی

</div>
