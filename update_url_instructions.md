# Railway Deploy Sonrası URL Güncelleme

## 1. Railway URL'yi Al
Railway dashboard'da deploy olduktan sonra verilen URL'yi kopyala:
- Örnek: `https://sendpic-face-api-production.up.railway.app`

## 2. Flutter'da URL'yi Güncelle
`lib/data/services/face_recognition_service.dart` dosyasında:

```dart
static const String _baseUrl = 'https://sendpic-face-api-production.up.railway.app';
```

## 3. Yeni APK Oluştur
```bash
flutter build apk --release
```

## 4. Test Et
- APK'yı yükle
- Uygulamayı aç
- Kayıt ol
- Fotoğraf çek
- Gönder
- Discover'da gör
