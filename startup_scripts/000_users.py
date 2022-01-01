import sys

from django.contrib.auth.models import User
from users.models import Token

from startup_script_utils import load_yaml

users = load_yaml("/opt/peering-manager/initializers/users.yml")
if not users:
    sys.exit()

for username, details in users.items():
    if not User.objects.filter(username=username):
        api_token = details.pop("api_token", "")
        user = User.objects.create_user(
            username=username,
            password=details.pop("password", "") or User.objects.make_random_password(),
            **details,
        )

        print(f"👤 Created user '{username}'")

        if api_token:
            Token.objects.create(user=user, key=api_token)
