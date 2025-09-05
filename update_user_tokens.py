#!/usr/bin/env python3
"""
Mevcut kullanıcıların jetonlarını 1000'e güncelle
"""

import os
import sys
from supabase import create_client, Client

# Supabase bilgileri
SUPABASE_URL = "https://tdxfwcgqesvgrdqidxik.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

def update_user_tokens():
    try:
        # Supabase client oluştur
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print("🔄 Mevcut kullanıcıların jetonları güncelleniyor...")
        
        # Tüm kullanıcıları getir
        users_response = supabase.table('users').select('id, email, name').execute()
        users = users_response.data
        
        if not users:
            print("❌ Kullanıcı bulunamadı!")
            return
        
        print(f"📊 {len(users)} kullanıcı bulundu")
        
        # Her kullanıcı için jeton güncelle
        for user in users:
            user_id = user['id']
            email = user['email']
            name = user['name']
            
            print(f"🔄 {name} ({email}) jetonları güncelleniyor...")
            
            # Mevcut jeton kaydını kontrol et
            tokens_response = supabase.table('user_tokens').select('*').eq('user_id', user_id).execute()
            
            if tokens_response.data:
                # Mevcut kaydı güncelle
                update_result = supabase.table('user_tokens').update({
                    'photo_tokens': 1000,
                    'video_tokens': 1000,
                    'premium_tokens': 0,
                    'updated_at': 'now()'
                }).eq('user_id', user_id).execute()
                
                if update_result.data:
                    print(f"✅ {name} jetonları güncellendi: 1000 foto + 1000 video")
                else:
                    print(f"❌ {name} jetonları güncellenemedi")
            else:
                # Yeni jeton kaydı oluştur
                insert_result = supabase.table('user_tokens').insert({
                    'user_id': user_id,
                    'photo_tokens': 1000,
                    'video_tokens': 1000,
                    'premium_tokens': 0
                }).execute()
                
                if insert_result.data:
                    print(f"✅ {name} için yeni jeton kaydı oluşturuldu: 1000 foto + 1000 video")
                else:
                    print(f"❌ {name} için jeton kaydı oluşturulamadı")
        
        print("\n🎉 Tüm kullanıcıların jetonları başarıyla güncellendi!")
        
    except Exception as e:
        print(f"❌ Hata: {e}")

if __name__ == "__main__":
    update_user_tokens()
