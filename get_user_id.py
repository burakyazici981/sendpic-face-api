#!/usr/bin/env python3
"""
Kullanıcı ID'sini al
"""

import os
import sys
from supabase import create_client, Client

# Supabase bilgileri
SUPABASE_URL = "https://tdxfwcgqesvgrdqidxik.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

def get_user_id():
    try:
        # Supabase client oluştur
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print("🔍 Kullanıcı ID'si alınıyor...")
        
        # Tüm kullanıcıları getir
        users_response = supabase.table('users').select('id, email, name').execute()
        users = users_response.data
        
        if not users:
            print("❌ Kullanıcı bulunamadı!")
            return
        
        for user in users:
            print(f"👤 {user['name']} ({user['email']})")
            print(f"🆔 User ID: {user['id']}")
            print()
        
    except Exception as e:
        print(f"❌ Hata: {e}")

if __name__ == "__main__":
    get_user_id()
