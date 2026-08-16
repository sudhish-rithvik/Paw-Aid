import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from app.supabase_client import get_supabase

supabase = get_supabase()
users = supabase.auth.admin.list_users()
for u in users:
    print(u.email)
