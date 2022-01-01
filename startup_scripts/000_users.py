import sys

from django.contrib.auth.models import User
from users.models import Token

from startup_script_utils import load_yaml

users = load_yaml("/opt/peering-manager/initializers/users.yml")
if not users:
    sys.exit()

for username, details in users.items():
    if not User.objects.filter(username=username):
        user = User.objects.create_user(
            username=username,
            password=details.get("password") or User.objects.make_random_password(),
        )

        print(f"👤 Created user '{username}'")

        if details.get("api_token"):
            Token.objects.create(user=user, key=details["api_token"])
