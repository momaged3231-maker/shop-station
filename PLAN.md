# محطة الصيانة - الخطة التنفيذية (نظامك الخاص - بدون iVentoy)

## ما تم انجازه اليوم (موثق)
- [x] هيكل `D:\Station\` كامل
- [x] ملفات الاقلاع الرسمية (تم التحقق بالحجم):
  - `netboot\ipxe\undionly.kpxe` (72KB - BIOS) من boot.ipxe.org
  - `netboot\ipxe\ipxe.efi` (1.1MB - UEFI64) من boot.ipxe.org
  - `netboot\ipxe\snponly.efi` (305KB - UEFI بديل) من boot.ipxe.org
  - `netboot\ipxe\wimboot` (76KB - v2.9.0) من github.com/ipxe/wimboot
- [x] `pxe_config.ini` - كل الاعدادات في ملف واحد
- [x] `netboot\menu.ipxe` - قايمة باسم محلك
- [x] `server\dhcp_server.py` + `tftp_server.py` + `http_server.py` + `run_all.py` (stdlib فقط - بدون pip)
- [x] `tools\install_prereqs.bat` - سكربت الادمن

## تحذيرات حرجة (تجنب الاخطاء)
1. **انا حاليا مش ادمن** - تثبيت Python/ADK وفتح بورت 67/69 وعمل الشير لازم Run as Administrator.
2. **عندك كرت شبكة واحد** على 10.0.0.39 (نت المحل). شبكة النشر لازم تبقى معزولة `192.168.10.0/24` والسيرفر `192.168.10.1`.
   الحل الصح: كرت USB-Ethernet تاني رخيص للنشر، الاساسي يفضل للنت. البديل المؤقت: تغيير IP الكرت يدوي وقت النشر فقط.
3. **اوعى توصل سويتش النشر على الراوتر** - سيرفر DHCP بتاعك هيضرب نت المحل كله. سويتش منفصل تماما.
4. **Secure Boot**: ملفات iPXE الحالية غير موقعة - اقفله على اجهزة العملاء وقت البوت الشبكي (ترجعه بعد التسطيب).
5. **TFTP للصغير فقط** - ملفات WIM الكبيرة عبر HTTP:8080 و SMB على 1Gbps. ده متعمد للسرعة.

## الخطوات الجاية بالترتيب
### الخطوة 1 - انت تعملها (ادمن - 10 دقايق)
1. كليك يمين على `D:\Station\tools\install_prereqs.bat` - Run as administrator
2. هيتثبت Python 3.12 + قواعد الفايروول (67/69/8080/445) + شير `\\SERVER\Station`

### الخطوة 2 - انت تعملها (تحميل كبير - بالليل)
1. من صفحة `learn.microsoft.com - Download and install the Windows ADK` نزل:
   - Windows ADK 10.1.26100.9457 سبتمبر 2026 (ملفا التثبيت جاهزان في tools\ - شغلهما كادمن، واختر Deployment Tools فقط)
   - Windows PE add-on لنفس الاصدار (adkwinpesetup.exe بجانبه)
2. ISOs الرسمية من `microsoft.com/software-download`: Win11 + Win10 22H2 + LTSC 2021

### الخطوة 3 - انا اعملها (بعد 1+2)
1. ابني `boot.wim + boot.sdi` بتاعتك بـ ADK مع سكربتات الشبكة والتعريفات
2. افحص كود البايثون بـ `python -m py_compile` واصلح اي خطأ
3. اختبار كامل على VM (Hyper-V) قبل اي جهاز حقيقي: DHCP Offer/ACK + TFTP + HTTP + قايمة البوت

### الخطوة 4 - التشغيل اليومي
1. وصل جهاز العميل على سويتش النشر المعزول
2. شغل `python D:\Station\server\run_all.py` كادمن
3. من جهاز العميل: Boot Menu - Network/PXE - اختار النسخة من قايمتك
4. بعد الويندوز: `\\192.168.10.1\Station\Drivers` ثم `\Apps`

## مسار الشبكة (كرت واحد - proxyDHCP)
```
[سيرفرك 10.0.0.39 static] --- سويتش المحل (مع الراوتر عادي) --- [اجهزة العملاء]
  الراوتر يوزع IPs + سيرفرك يرد على البوت فقط: proxyDHCP(4011) + TFTP(69) + HTTP(8080) + SMB(445)
```
ممنوع وضع full DHCP على هذه الشبكة (pxe_config.ini mode=proxy).

## ملفات التخصيص
- تغيير اسم المحل/الاختيارات: `netboot\menu.ipxe`
- تغيير IPs/النطاق: `pxe_config.ini`
- اللوجات: `D:\Station\logs\`
