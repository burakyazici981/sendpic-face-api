# SendPic Face Recognition Server

Gelişmiş yüz tanıma, cinsiyet tespiti, anti-spoofing ve YOLO entegrasyonu ile kapsamlı bir yüz analiz sistemi.

## Özellikler

### 🔍 Yüz Tanıma
- **FaceNet** ile yüksek doğrulukta yüz tanıma
- **MTCNN** ile yüz tespiti
- Yüz embedding'leri ile kimlik doğrulama
- Bilinen yüzleri veritabanında saklama

### 👥 Cinsiyet Tespiti
- Derin öğrenme ile cinsiyet sınıflandırması
- Yaş tahmini
- Yüz özellik analizi
- Yüksek doğruluk oranı

### 🛡️ Anti-Spoofing
- Fotoğraf saldırılarını tespit etme
- Video/screen replay saldırılarını tespit etme
- 3D maske tespiti
- Risk skorlama sistemi

### 🎯 YOLO Entegrasyonu
- YOLOv8 ile nesne tespiti
- Yüz tespiti için YOLO optimizasyonu
- Gerçek zamanlı işleme
- Çoklu model desteği

### 🗄️ Veritabanı
- SQLite/PostgreSQL desteği
- Yüz embedding'leri saklama
- İşlem logları
- Performans takibi

## Kurulum

### Gereksinimler
- Python 3.8+
- CUDA desteği (opsiyonel, GPU için)
- 8GB+ RAM önerilir

### 1. Bağımlılıkları Yükleyin
```bash
pip install -r requirements.txt
```

### 2. Modelleri İndirin
```bash
python utils/download_models.py
```

### 3. Veritabanını Başlatın
```bash
python -c "from database.connection import init_database; init_database()"
```

### 4. Sunucuyu Başlatın
```bash
python main.py
```

## API Kullanımı

### Yüz Tanıma
```bash
curl -X POST "http://localhost:8000/api/v1/recognize" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@image.jpg"
```

### Yüz Ekleme
```bash
curl -X POST "http://localhost:8000/api/v1/add-face" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@face.jpg" \
  -F "user_id=user123" \
  -F "name=John Doe"
```

### Servis İstatistikleri
```bash
curl "http://localhost:8000/api/v1/stats"
```

## API Endpoints

| Endpoint | Method | Açıklama |
|----------|--------|----------|
| `/` | GET | Sağlık kontrolü |
| `/health` | GET | Detaylı sağlık kontrolü |
| `/api/v1/recognize` | POST | Yüz tanıma |
| `/api/v1/add-face` | POST | Yüz ekleme |
| `/api/v1/stats` | GET | Servis istatistikleri |
| `/api/v1/faces` | GET | Bilinen yüzler |
| `/api/v1/faces/{user_id}` | DELETE | Yüz silme |

## Yapılandırma

`config.py` dosyasında aşağıdaki ayarları yapabilirsiniz:

```python
# Yüz tespiti eşiği
FACE_DETECTION_CONFIDENCE = 0.5

# Yüz tanıma eşiği  
FACE_RECOGNITION_THRESHOLD = 0.6

# Anti-spoofing eşiği
ANTI_SPOOF_THRESHOLD = 0.5

# Cinsiyet tespiti eşiği
GENDER_CONFIDENCE_THRESHOLD = 0.7
```

## Model Performansı

### Desteklenen Modeller
- **YOLOv8**: Nesne ve yüz tespiti
- **FaceNet**: Yüz tanıma
- **MTCNN**: Yüz tespiti
- **Custom CNN**: Cinsiyet tespiti
- **Custom CNN**: Anti-spoofing

### Performans Metrikleri
- Yüz tespiti: ~95% doğruluk
- Yüz tanıma: ~98% doğruluk
- Cinsiyet tespiti: ~92% doğruluk
- Anti-spoofing: ~90% doğruluk

## Geliştirme

### Test Etme
```bash
pytest tests/
```

### Kod Formatı
```bash
black .
flake8 .
```

### Docker ile Çalıştırma
```bash
docker build -t face-recognition-server .
docker run -p 8000:8000 face-recognition-server
```

## Flutter Entegrasyonu

Bu Python sunucusu Flutter uygulamanızla entegre edilebilir:

1. **HTTP İstekleri**: `http` paketi ile API çağrıları
2. **Dosya Yükleme**: `multipart/form-data` ile resim yükleme
3. **JSON Parsing**: `dart:convert` ile yanıt işleme

### Flutter Örnek Kodu
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> recognizeFace(File imageFile) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('http://localhost:8000/api/v1/recognize'),
  );
  
  request.files.add(
    await http.MultipartFile.fromPath('file', imageFile.path),
  );
  
  var response = await request.send();
  var responseData = await response.stream.bytesToString();
  
  return json.decode(responseData);
}
```

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## Destek

Sorularınız için issue açabilir veya iletişime geçebilirsiniz.