import sys

from django.contrib.auth.models import Group, User

from startup_script_utils import load_yaml

groups = load_yaml("/opt/peering-manager/initializers/groups.yml")
if not groups:
    sys.exit()

for name, details in groups.items():
    group, created = Group.objects.get_or_create(name=name)

    if created:
        print(f"👥 Created group '{name}'")

    for username in details.get("users", []):
        user = User.objects.get(username=username)

        if user:
            group.user_set.add(user)
            print(f" 👤 Assigned user '{username}' to group '{group.name}'")

    group.save()
