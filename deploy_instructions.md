# SendPic Uygulaması Deploy Talimatları

## 🚀 Proje Durumu
- ✅ Flutter APK başarıyla oluşturuldu (53.6MB)
- ✅ Backend servisi çalışıyor (Port 5050)
- ✅ Supabase veritabanı hazır
- ✅ Yapay zeka modelleri yüklendi

## 📱 APK Dosyası
**Konum:** `build\app\outputs\flutter-apk\app-release.apk`
**Boyut:** 53.6MB
**Durum:** Test için hazır

## 🔧 Backend Servisi
**Port:** 5050
**URL:** http://localhost:5050
**Durum:** Çalışıyor ✅

### Backend Başlatma
```bash
cd face_recognition_server
python main.py
```

### Test Endpoint'leri
- Health Check: `GET http://localhost:5050/health`
- Face Recognition: `POST http://localhost:5050/api/v1/recognize`
- Face Detection: `POST http://localhost:5050/test/face-detection`

## 🗄️ Veritabanı (Supabase)
**URL:** https://tdxfwcgqesvgrdqidxik.supabase.co
**Durum:** Cloud'da çalışıyor ✅

## 🤖 Yapay Zeka Modelleri
- **Yüz Tespiti:** Haar Cascade + Custom Features
- **Yüz Tanıma:** MTCNN + FaceNet
- **Cinsiyet Tespiti:** TensorFlow
- **Anti-Spoofing:** Custom Model
- **YOLO:** Object Detection

## 📋 Deploy Adımları

### 1. APK Kurulumu
1. `app-release.apk` dosyasını Android cihaza kopyalayın
2. "Bilinmeyen kaynaklardan uygulama yükleme" iznini verin
3. APK dosyasını açın ve kurun

### 2. Backend Servisi
**Yerel Kullanım:**
```bash
cd face_recognition_server
python main.py
```

**Production Deploy (Önerilen):**
- Heroku, Railway, veya DigitalOcean kullanın
- Port 5050'i açık tutun
- Environment variables ayarlayın

### 3. Ağ Konfigürasyonu
- Flutter uygulaması `localhost:5050` adresini kullanıyor
- Production'da backend URL'ini güncelleyin:
  ```dart
  // lib/data/services/face_recognition_service.dart
  static const String _baseUrl = 'https://your-backend-url.com';
  ```

## 🔍 Test Senaryoları

### 1. Temel Test
- [ ] Uygulama açılıyor
- [ ] Backend bağlantısı başarılı
- [ ] Kamera izinleri veriliyor

### 2. Yüz Tanıma Test
- [ ] Resim seçme çalışıyor
- [ ] Yüz tespiti yapılıyor
- [ ] Sonuçlar gösteriliyor

### 3. Gelişmiş Test
- [ ] Cinsiyet tespiti
- [ ] Anti-spoofing
- [ ] Geçmiş kayıtları

## ⚠️ Önemli Notlar

1. **Backend Gereksinimi:** Yapay zeka modelleri için backend servisi zorunlu
2. **İnternet Bağlantısı:** Supabase için gerekli
3. **Depolama:** Modeller için ~2GB disk alanı
4. **RAM:** En az 4GB önerilir

## 🐛 Sorun Giderme

### APK Kurulum Hatası
- Android sürümünü kontrol edin (min: API 21)
- Depolama alanını kontrol edin
- İzinleri kontrol edin

### Backend Bağlantı Hatası
- Port 5050'in açık olduğunu kontrol edin
- Firewall ayarlarını kontrol edin
- URL'yi doğrulayın

### Yapay Zeka Hatası
- Modellerin yüklendiğini kontrol edin
- RAM kullanımını kontrol edin
- Log dosyalarını inceleyin

## 📞 Destek
Herhangi bir sorun için log dosyalarını kontrol edin:
- Backend: `face_recognition_server/logs/`
- Flutter: Android Studio Logcat

---
**Deploy Tarihi:** 5 Eylül 2025
**Versiyon:** 1.0.0
**Durum:** Production Ready ✅
