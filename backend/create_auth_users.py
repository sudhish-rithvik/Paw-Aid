import asyncio
import sys
from pathlib import Path

# Ensure app package is importable
sys.path.insert(0, str(Path(__file__).parent))

from app.supabase_client import get_supabase

def create_users():
    supabase = get_supabase()
    
    users = [
        {"email": "admin@pawaid.com", "password": "password123", "role": "admin", "display_name": "Admin User"},
        {"email": "ngo@pawaid.com", "password": "password123", "role": "ngo_staff", "display_name": "NGO Worker"},
        {"email": "citizen@pawaid.com", "password": "password123", "role": "citizen", "display_name": "Helpful Citizen"},
    ]
    
    for u in users:
        try:
            print(f"Creating user {u['email']}...")
            resp = supabase.auth.admin.create_user({
                "email": u["email"],
                "password": u["password"],
                "email_confirm": True,
                "user_metadata": {"display_name": u["display_name"]}
            })
            print(f"Success! ID: {resp.user.id}")
            
            # Update the profile to set the role correctly
            supabase.table("profiles").update({"role": u["role"]}).eq("id", resp.user.id).execute()
            print(f"Role set to {u['role']}")
            
        except Exception as e:
            print(f"Failed (might already exist?): {e}")

if __name__ == "__main__":
    create_users()
