#!/usr/bin/env python3
"""
Mevcut kullanıcıları kontrol et ve jeton ver
"""

import asyncio
from supabase import create_client, Client

# Supabase bağlantısı
url = "https://tdxfwcgqesvgrdqidxik.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

supabase: Client = create_client(url, key)

async def check_and_update_users():
    """Mevcut kullanıcıları kontrol et ve jeton ver"""
    
    print("🔍 Mevcut kullanıcılar kontrol ediliyor...")
    
    try:
        # Kullanıcıları al
        users_response = supabase.table("users").select("id, email, name").execute()
        
        if not users_response.data:
            print("   ❌ Kullanıcı bulunamadı")
            return
        
        print(f"   👥 {len(users_response.data)} kullanıcı bulundu")
        
        for user in users_response.data:
            user_id = user["id"]
            email = user["email"]
            name = user["name"]
            
            print(f"\n📝 {name} ({email})")
            
            # Mevcut token kaydını kontrol et
            tokens_response = supabase.table("user_tokens").select("*").eq("user_id", user_id).execute()
            
            if tokens_response.data:
                # Mevcut kaydı güncelle
                update_response = supabase.table("user_tokens").update({
                    "photo_tokens": 1000,
                    "video_tokens": 1000,
                    "premium_tokens": 0,
                }).eq("user_id", user_id).execute()
                
                if update_response.data:
                    print(f"   ✅ Tokenlar güncellendi: 1000 fotoğraf + 1000 video")
                else:
                    print(f"   ❌ Token güncelleme başarısız")
            else:
                # Yeni token kaydı oluştur
                insert_response = supabase.table("user_tokens").insert({
                    "user_id": user_id,
                    "photo_tokens": 1000,
                    "video_tokens": 1000,
                    "premium_tokens": 0,
                }).execute()
                
                if insert_response.data:
                    print(f"   ✅ Yeni token kaydı oluşturuldu: 1000 fotoğraf + 1000 video")
                else:
                    print(f"   ❌ Token kaydı oluşturulamadı")
        
        # Son durumu kontrol et
        print("\n🔍 Son durum kontrol ediliyor...")
        final_tokens = supabase.table("user_tokens").select("photo_tokens, video_tokens").execute()
        
        if final_tokens.data:
            total_photo = sum(token["photo_tokens"] for token in final_tokens.data)
            total_video = sum(token["video_tokens"] for token in final_tokens.data)
            print(f"   📊 Toplam fotoğraf jetonu: {total_photo}")
            print(f"   📊 Toplam video jetonu: {total_video}")
            print(f"   👥 Token sahibi kullanıcı: {len(final_tokens.data)}")
        
    except Exception as e:
        print(f"❌ Hata: {e}")

if __name__ == "__main__":
    asyncio.run(check_and_update_users())
