#!/usr/bin/env python3
"""
Manuel olarak jeton kayıtları oluştur
"""

import os
import sys
from supabase import create_client, Client

# Supabase bilgileri
SUPABASE_URL = "https://tdxfwcgqesvgrdqidxik.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

def create_tokens_manually():
    try:
        # Supabase client oluştur
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print("🔄 Manuel jeton kayıtları oluşturuluyor...")
        
        # Tüm kullanıcıları getir
        users_response = supabase.table('users').select('id, email, name').execute()
        users = users_response.data
        
        if not users:
            print("❌ Kullanıcı bulunamadı!")
            return
        
        print(f"📊 {len(users)} kullanıcı bulundu")
        
        # Her kullanıcı için jeton kaydı oluştur
        for user in users:
            user_id = user['id']
            email = user['email']
            name = user['name']
            
            print(f"🔄 {name} ({email}) için jeton kaydı oluşturuluyor...")
            
            # Jeton kaydı oluştur
            token_data = {
                "user_id": user_id,
                "photo_tokens": 1000,
                "video_tokens": 1000,
                "premium_tokens": 0
            }
            
            try:
                # Direct insert without RLS
                insert_result = supabase.table('user_tokens').insert(token_data).execute()
                
                if insert_result.data:
                    print(f"✅ {name} için jeton kaydı oluşturuldu: 1000 foto + 1000 video")
                else:
                    print(f"❌ {name} için jeton kaydı oluşturulamadı: {insert_result}")
            except Exception as e:
                print(f"❌ {name} için hata: {e}")
        
        print("\n🎉 Jeton kayıtları oluşturma işlemi tamamlandı!")
        
    except Exception as e:
        print(f"❌ Hata: {e}")

if __name__ == "__main__":
    create_tokens_manually()
