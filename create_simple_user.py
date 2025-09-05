#!/usr/bin/env python3
"""
Basit test kullanıcısı oluştur
"""

import asyncio
from supabase import create_client, Client

# Supabase bağlantısı
url = "https://tdxfwcgqesvgrdqidxik.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

supabase: Client = create_client(url, key)

async def create_simple_user():
    """Basit test kullanıcısı oluştur"""
    
    print("🚀 Test kullanıcısı oluşturuluyor...")
    
    try:
        # Test kullanıcısı bilgileri
        email = "burak.test@gmail.com"
        password = "123456"
        name = "Test User"
        
        print(f"📝 {name} ({email}) oluşturuluyor...")
        
        # 1. Kullanıcıyı Supabase Auth'da oluştur
        auth_response = supabase.auth.sign_up({
            "email": email,
            "password": password
        })
        
        if auth_response.user:
            user_id = auth_response.user.id
            print(f"   ✅ Auth kullanıcısı oluşturuldu: {user_id}")
            
            # 2. Kullanıcı profilini oluştur
            profile_response = supabase.table("users").insert({
                "id": user_id,
                "email": email,
                "name": name,
                "is_verified": True,
                "age": 25,
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
                    print(f"\n🎉 Test kullanıcısı başarıyla oluşturuldu!")
                    print(f"   📧 Email: {email}")
                    print(f"   🔑 Şifre: {password}")
                    print(f"   🪙 Jeton: 1000 fotoğraf + 1000 video")
                else:
                    print(f"   ❌ Jeton verilemedi: {token_response}")
            else:
                print(f"   ❌ Profil oluşturulamadı: {profile_response}")
        else:
            print(f"   ❌ Auth kullanıcısı oluşturulamadı: {auth_response}")
            
    except Exception as e:
        print(f"   ❌ Hata: {e}")

if __name__ == "__main__":
    asyncio.run(create_simple_user())
