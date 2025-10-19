"""
Script per generare la chiave di encryption per i token OAuth2.
Esegui con: python generate_encryption_key.py
"""
from cryptography.fernet import Fernet

# Genera una nuova chiave di encryption
key = Fernet.generate_key()
print("=" * 60)
print("🔐 CHIAVE DI ENCRYPTION GENERATA")
print("=" * 60)
print("\nCopia questa chiave e usala nel comando firebase:")
print(f"\n{key.decode()}\n")
print("=" * 60)
print("\n⚠️  IMPORTANTE: Conserva questa chiave in modo sicuro!")
print("   Se la perdi, dovrai rigenerare tutti i token degli utenti.")
print("=" * 60)

