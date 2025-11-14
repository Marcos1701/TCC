import os
import django
import sys

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

# Print the actual file path being imported
import finance.serializers
print(f"Importing from: {finance.serializers.__file__}")
print()

from finance.serializers import MissionSerializer

# Read the actual file
with open(finance.serializers.__file__, 'r', encoding='utf-8') as f:
    content = f.read()
    # Find the fields = line
    start_idx = content.find('class MissionSerializer')
    meta_idx = content.find('fields = [', start_idx)
    end_idx = content.find(']', meta_idx)
    fields_section = content[meta_idx:end_idx+1]
    print("===FIELDS IN SOURCE FILE===")
    print(fields_section[:500])
    print()

print("===ACTUAL FIELDS IN Meta.fields (what Python sees)===")
for f in MissionSerializer.Meta.fields:
    print(f"  - {f}")

print("\n===DECLARED FIELDS===")
for name, field in MissionSerializer._declared_fields.items():
    print(f"  - {name}: {type(field).__name__}")
