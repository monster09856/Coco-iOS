# Coco — Play Console Data Safety Form Draft

Bu form Play Console'da "App content → Data safety" altında doldurulacak. Aşağıdaki cevapları **tek tek soruyla eşleştir** ve uygula.

---

## Section 1 — Data collection & security

### Does your app collect or share any of the required user data types?
**YES** — uygulama Firebase Auth + FCM + AdMob + Crashlytics + IAP kullanır.

### Is all of the user data collected by your app encrypted in transit?
**YES** — Firebase tüm bağlantıları TLS 1.2+ ile yapar. AdMob HTTPS kullanır.

### Do you provide a way for users to request that their data is deleted?
**YES** — `dostocomp@gmail.com` adresinden talep edilebilir. Privacy policy'de açıkça belirtilmiş.

### Has your app been independently validated against a global security standard?
**NO** — bağımsız audit yapılmadı.

---

## Section 2 — Data types collected (✓ = collected, ✗ = not collected)

### Personal info
- **Name** ✓ — opsiyonel (Apple/Google sign-in sonrası), kullanıcı profili için
- **Email address** ✓ — opsiyonel (sign-in sonrası), hesap kimliği için
- **User IDs** ✓ — Firebase UID, hesap ile ilişkilendirme için
- Address ✗, Phone number ✗, Race/ethnicity ✗, Political/religious beliefs ✗
- **Other personal info** ✗

### Financial info
- **Purchase history** ✓ — IAP geçmişi, premium feature unlock için
- User payment info ✗ — Google Play handles, app görmez
- Credit score ✗, Other financial info ✗

### Location
- Approximate location ✗
- Precise location ✗

### Health & fitness
- ✗ — toplanmıyor

### Messages
- ✗ — toplanmıyor

### Photos and videos
- ✗ — toplanmıyor

### Audio files
- ✗ — toplanmıyor

### Files and docs
- ✗ — toplanmıyor

### Calendar
- ✗ — toplanmıyor

### Contacts
- ✗ — toplanmıyor

### App activity
- **App interactions** ✓ — level başarısı, in-app navigation, Firebase Analytics
- **In-app search history** ✗
- **Installed apps** ✗
- **Other user-generated content** ✗
- **Other actions** ✓ — gameplay events (level complete, fail, IAP attempt)

### Web browsing
- ✗

### App info and performance
- **Crash logs** ✓ — Firebase Crashlytics, hata raporlama için
- **Diagnostics** ✓ — performance metrics
- **Other app performance data** ✗

### Device or other IDs
- **Device or other IDs** ✓ — IDFA/Advertising ID, AdMob targeting için (ATT permission'ı kullanıcıya verilir, reddederse personalized ads kapanır)

---

## Section 3 — Purposes per data type

| Data type | App functionality | Analytics | Communication | Advertising | Fraud prevention | Compliance | Account management | Developer comm |
|---|---|---|---|---|---|---|---|---|
| Name | ✓ | | | | | | ✓ | |
| Email | ✓ | | | | | | ✓ | |
| User IDs | ✓ | ✓ | | | ✓ | ✓ | ✓ | |
| Purchase history | ✓ | ✓ | | | | ✓ | ✓ | |
| App interactions | ✓ | ✓ | | | | | | |
| Gameplay events | ✓ | ✓ | | | | | | |
| Crash logs | ✓ | ✓ | | | | | | |
| Diagnostics | ✓ | ✓ | | | | | | |
| Device IDs | | ✓ | | ✓ | ✓ | | | |

---

## Section 4 — Optional vs required

For each data type:
- Name → **Optional** (sign-in optional)
- Email → **Optional**
- User IDs → **Optional**
- Purchase history → **Required** (only if user makes purchase)
- App interactions → **Required** (telemetry default-on, no user opt-out)
- Crash logs → **Required**
- Diagnostics → **Required**
- Device IDs → **Optional** (ATT permission dependent)

---

## Section 5 — Sharing

For each data type, is it shared with third parties?

- Name: **NO** (in app only)
- Email: **NO**
- User IDs: **NO**
- Purchase history: **NO** (Google handles transaction)
- App interactions: **NO** (Firebase Analytics — Google as data processor, not 3rd party)
- Gameplay events: **NO**
- Crash logs: **NO** (Firebase Crashlytics — Google as data processor)
- Diagnostics: **NO**
- **Device IDs: YES** ⚠️ — shared with **AdMob** for advertising

For AdMob (Device IDs sharing):
- **Purposes**: Advertising or marketing, Analytics
- **Optional**: YES (user can deny via ATT)
- **Processed ephemerally**: NO

---

## Section 6 — Encryption & deletion

- **Is data encrypted in transit?** YES (Firebase + AdMob HTTPS only)
- **Can users request data deletion?** YES — via email `dostocomp@gmail.com`

---

## Privacy Policy URL

When form asks for it:
- **TR:** https://dosto.tr/coco/gizlilik (eğer hazırsa) veya https://ilacbilgi.org/privacy-policy.html (genel)
- **EN:** https://dosto.tr/coco/privacy

NOT: `dosto.tr/coco/` altında Coco-specific privacy policy YAYINLAMAMIŞSAN, hızlıca bir tane yazıp deploy etmem gerek. Söyle, hallederiz.

---

## Submitting

After all answers entered:
1. **Save draft** — kaydet
2. **Submit for review** — Play Console internal scan yapar
3. Geri bildirim varsa düzeltirsin (genelde 24h içinde)

---

# Bonus — Privacy Policy URL eksikse hızlı placeholder

Coco için Play Store geçmeden privacy policy yayınlamamız ZORUNLU. Aşağıdaki gibi bir sayfa hazırla:

**URL**: https://dosto.tr/coco/gizlilik

İçerik (Turkish):
"Coco - Eşleştirme Macerası uygulaması, Sedat Erdemci (Dostocomp) tarafından geliştirilmiştir.

**Topladığımız veriler:**
- Hesap (opsiyonel): ad, e-posta — Apple/Google Sign-In üzerinden
- Cihaz ID'si — AdMob reklam için (ATT izninizle)
- Kullanım: level başarımı, çökme raporu — Firebase Analytics + Crashlytics

**Paylaşım:**
- Reklam ortaklarımız: Google AdMob (cihaz ID'si)
- Diğer hiçbir üçüncü tarafla paylaşılmaz

**Veri silme talebi:**
dostocomp@gmail.com adresine yazarak hesap silme + tüm veri imhasını talep edebilirsiniz.

**İletişim:**
Sedat Erdemci · Dostocomp · dostocomp@gmail.com"

Söyle, sayfayı oluşturup deploy edeyim.
