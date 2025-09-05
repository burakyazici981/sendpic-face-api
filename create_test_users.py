#!/usr/bin/env python3
"""
Test kullanıcıları oluşturma ve 1000 jeton verme scripti
"""

import asyncio
import os
from supabase import create_client, Client
from dotenv import load_dotenv

# Supabase bağlantısı (doğrudan değerler)
url = "https://tdxfwcgqesvgrdqidxik.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

supabase: Client = create_client(url, key)

# Test kullanıcıları
TEST_USERS = [
    {"name": "Test User 1", "email": "test1@gmail.com", "password": "123456"},
    {"name": "Test User 2", "email": "test2@gmail.com", "password": "123456"},
    {"name": "Test User 3", "email": "test3@gmail.com", "password": "123456"},
    {"name": "Test User 4", "email": "test4@gmail.com", "password": "123456"},
    {"name": "Test User 5", "email": "test5@gmail.com", "password": "123456"},
    {"name": "Test User 6", "email": "test6@gmail.com", "password": "123456"},
    {"name": "Test User 7", "email": "test7@gmail.com", "password": "123456"},
    {"name": "Test User 8", "email": "test8@gmail.com", "password": "123456"},
    {"name": "Test User 9", "email": "test9@gmail.com", "password": "123456"},
    {"name": "Test User 10", "email": "test10@gmail.com", "password": "123456"},
]

async def create_test_users():
    """Test kullanıcılarını oluştur ve 1000 jeton ver"""
    
    print("🚀 Test kullanıcıları oluşturuluyor...")
    
    created_count = 0
    token_given_count = 0
    
    for user_data in TEST_USERS:
        try:
            print(f"\n📝 {user_data['name']} oluşturuluyor...")
            
            # 1. Kullanıcıyı Supabase Auth'da oluştur
            auth_response = supabase.auth.sign_up({
                "email": user_data["email"],
                "password": user_data["password"]
            })
            
            if auth_response.user:
                user_id = auth_response.user.id
                print(f"   ✅ Auth kullanıcısı oluşturuldu: {user_id}")
                
                # 2. Kullanıcı profilini oluştur
                profile_response = supabase.table("users").insert({
                    "id": user_id,
                    "email": user_data["email"],
                    "name": user_data["name"],
                    "is_verified": True,
                    "birth_date": "1990-01-01",  # Varsayılan doğum tarihi
                }).execute()
                
                if profile_response.data:
                    print(f"   ✅ Profil oluşturuldu")
                    
                    # 3. Kullanıcıya 1000 jeton ver
                    token_response = supabase.table("user_tokens").insert({
                        "user_id": user_id,
                        "photo_tokens": 1000,
                        "video_tokens": 1000,
                        "premium_tokens": 0,
                    }).execute()
                    
                    if token_response.data:
                        print(f"   ✅ 1000 fotoğraf + 1000 video jetonu verildi")
                        token_given_count += 1
                    else:
                        print(f"   ❌ Jeton verilemedi: {token_response}")
                else:
                    print(f"   ❌ Profil oluşturulamadı: {profile_response}")
            else:
                print(f"   ❌ Auth kullanıcısı oluşturulamadı: {auth_response}")
                
        except Exception as e:
            print(f"   ❌ Hata: {e}")
        
        created_count += 1
    
    print(f"\n🎉 İşlem tamamlandı!")
    print(f"   📊 Oluşturulan kullanıcı: {created_count}")
    print(f"   🪙 Jeton verilen kullanıcı: {token_given_count}")

async def give_tokens_to_existing_users():
    """Mevcut kullanıcılara 1000 jeton ver"""
    
    print("🪙 Mevcut kullanıcılara jeton veriliyor...")
    
    try:
        # Tüm kullanıcıları al
        users_response = supabase.table("users").select("id").execute()
        
        if not users_response.data:
            print("   ❌ Kullanıcı bulunamadı")
            return
        
        updated_count = 0
        
        for user in users_response.data:
            user_id = user["id"]
            
            try:
                # Mevcut token kaydını kontrol et
                existing_tokens = supabase.table("user_tokens").select("*").eq("user_id", user_id).execute()
                
                if existing_tokens.data:
                    # Mevcut kaydı güncelle
                    update_response = supabase.table("user_tokens").update({
                        "photo_tokens": 1000,
                        "video_tokens": 1000,
                        "premium_tokens": 0,
                    }).eq("user_id", user_id).execute()
                    
                    if update_response.data:
                        print(f"   ✅ {user_id}: Tokenlar güncellendi")
                        updated_count += 1
                    else:
                        print(f"   ❌ {user_id}: Güncelleme başarısız")
                else:
                    # Yeni token kaydı oluştur
                    insert_response = supabase.table("user_tokens").insert({
                        "user_id": user_id,
                        "photo_tokens": 1000,
                        "video_tokens": 1000,
                        "premium_tokens": 0,
                    }).execute()
                    
                    if insert_response.data:
                        print(f"   ✅ {user_id}: Yeni token kaydı oluşturuldu")
                        updated_count += 1
                    else:
                        print(f"   ❌ {user_id}: Token kaydı oluşturulamadı")
                        
            except Exception as e:
                print(f"   ❌ {user_id}: Hata - {e}")
        
        print(f"\n🎉 Token işlemi tamamlandı!")
        print(f"   📊 Güncellenen kullanıcı: {updated_count}")
        
    except Exception as e:
        print(f"❌ Genel hata: {e}")

async def check_database_status():
    """Veritabanı durumunu kontrol et"""
    
    print("🔍 Veritabanı durumu kontrol ediliyor...")
    
    try:
        # Kullanıcı sayısı
        users_count = supabase.table("users").select("id", count="exact").execute()
        print(f"   👥 Toplam kullanıcı: {users_count.count}")
        
        # Token kayıtları
        tokens_count = supabase.table("user_tokens").select("id", count="exact").execute()
        print(f"   🪙 Token kaydı: {tokens_count.count}")
        
        # Ortalama token miktarları
        tokens_data = supabase.table("user_tokens").select("photo_tokens, video_tokens").execute()
        
        if tokens_data.data:
            total_photo_tokens = sum(token["photo_tokens"] for token in tokens_data.data)
            total_video_tokens = sum(token["video_tokens"] for token in tokens_data.data)
            avg_photo_tokens = total_photo_tokens / len(tokens_data.data)
            avg_video_tokens = total_video_tokens / len(tokens_data.data)
            
            print(f"   📊 Ortalama fotoğraf jetonu: {avg_photo_tokens:.1f}")
            print(f"   📊 Ortalama video jetonu: {avg_video_tokens:.1f}")
        
    except Exception as e:
        print(f"❌ Veritabanı kontrol hatası: {e}")

async def main():
    """Ana fonksiyon"""
    
    print("=" * 50)
    print("🎯 SendPic Test Kullanıcı Oluşturucu")
    print("=" * 50)
    
    # Önce durumu kontrol et
    await check_database_status()
    
    print("\n" + "=" * 50)
    
    # Test kullanıcılarını oluştur
    await create_test_users()
    
    print("\n" + "=" * 50)
    
    # Mevcut kullanıcılara jeton ver
    await give_tokens_to_existing_users()
    
    print("\n" + "=" * 50)
    
    # Son durumu kontrol et
    await check_database_status()
    
    print("\n🎉 Tüm işlemler tamamlandı!")

if __name__ == "__main__":
    asyncio.run(main())
