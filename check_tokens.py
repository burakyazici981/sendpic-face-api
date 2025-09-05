#!/usr/bin/env python3
"""
Mevcut kullanıcıların jeton durumunu kontrol et
"""

import os
import sys
from supabase import create_client, Client

# Supabase bilgileri
SUPABASE_URL = "https://tdxfwcgqesvgrdqidxik.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

def check_tokens():
    try:
        # Supabase client oluştur
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print("🔍 Mevcut kullanıcıların jeton durumu kontrol ediliyor...")
        
        # Tüm kullanıcıları getir
        users_response = supabase.table('users').select('id, email, name').execute()
        users = users_response.data
        
        if not users:
            print("❌ Kullanıcı bulunamadı!")
            return
        
        print(f"📊 {len(users)} kullanıcı bulundu\n")
        
        # Her kullanıcı için jeton durumunu kontrol et
        for user in users:
            user_id = user['id']
            email = user['email']
            name = user['name']
            
            print(f"👤 {name} ({email})")
            
            # Jeton kaydını kontrol et
            tokens_response = supabase.table('user_tokens').select('*').eq('user_id', user_id).execute()
            
            if tokens_response.data:
                tokens = tokens_response.data[0]
                print(f"   📸 Foto jetonları: {tokens.get('photo_tokens', 0)}")
                print(f"   🎥 Video jetonları: {tokens.get('video_tokens', 0)}")
                print(f"   ⭐ Premium jetonları: {tokens.get('premium_tokens', 0)}")
            else:
                print("   ❌ Jeton kaydı bulunamadı!")
            
            print()
        
    except Exception as e:
        print(f"❌ Hata: {e}")

if __name__ == "__main__":
    check_tokens()
