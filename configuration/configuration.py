import os
import re
import socket

# For reference see http://netbox.readthedocs.io/en/latest/configuration/mandatory-settings/
# Based on https://github.com/netbox-community/netbox/blob/develop/netbox/netbox/configuration.example.py

# Read secret from file
def read_secret(secret_name):
    try:
        f = open("/run/secrets/" + secret_name, "r", encoding="utf-8")
    except EnvironmentError:
        return ""
    else:
        with f:
            return f.readline().strip()


# This is a list of valid fully-qualified domain names (FQDNs) for this server.
# The server will not permit write access to the server via any other
# hostnames. The first FQDN in the list will be treated as the preferred name.
#
# Example: ALLOWED_HOSTS = ['peering.example.com', 'peering.internal.local']
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(" ")

# Must be unique to each setup (CHANGE IT!).
SECRET_KEY = os.environ.get("SECRET_KEY", read_secret("secret_key"))

# Base URL path if accessing Peering Manager within a directory.
BASE_PATH = os.environ.get("BASE_PATH", "")

# Time zone to use for date.
TIME_ZONE = os.environ.get("TIME_ZONE", "UTC")

# Autonomous System number
MY_ASN = int(os.environ.get("MY_ASN", 64512))

# PostgreSQL database configuration
DATABASE = {
    "NAME": os.environ.get("DB_NAME", "peering_manager"),  # Database name
    "USER": os.environ.get("DB_USER", ""),  # PostgreSQL username
    "PASSWORD": os.environ.get(
        "DB_PASSWORD", read_secret("db_password")
    ),  # PostgreSQL password
    "HOST": os.environ.get("DB_HOST", "localhost"),  # Database server
    "PORT": os.environ.get("DB_PORT", ""),  # Database port (leave blank for default)
    "OPTIONS": {"sslmode": os.environ.get("DB_SSLMODE", "prefer"),},
    "CONN_MAX_AGE": int(os.environ.get("DB_CONN_MAX_AGE", "300")),
}

# Redis configuration
REDIS = {
    "tasks": {
        "HOST": os.environ.get("REDIS_HOST", "localhost"),
        "PORT": int(os.environ.get("REDIS_PORT", 6379)),
        "PASSWORD": os.environ.get("REDIS_PASSWORD", read_secret("redis_password")),
        "CACHE_DATABASE": int(os.environ.get("REDIS_DATABASE", 0)),
        "DEFAULT_TIMEOUT": int(os.environ.get("REDIS_TIMEOUT", 300)),
        "SSL": os.environ.get("REDIS_SSL", "False").lower() == "true",
    },
    "caching": {
        "HOST": os.environ.get(
            "REDIS_CACHE_HOST", os.environ.get("REDIS_HOST", "localhost")
        ),
        "PORT": os.environ.get(
            "REDIS_CACHE_PORT",
            os.environ.get("REDIS_PORT", 6379)
        ),
        "PASSWORD": os.environ.get(
            "REDIS_CACHE_PASSWORD",
            os.environ.get("REDIS_PASSWORD", read_secret("redis_cache_password")),
        ),
        "CACHE_DATABASE": int(os.environ.get("REDIS_CACHE_DATABASE", 1)),
        "DEFAULT_TIMEOUT": int(
            os.environ.get("REDIS_CACHE_TIMEOUT", os.environ.get("REDIS_TIMEOUT", 300))
        ),
        "SSL": os.environ.get(
            "REDIS_CACHE_SSL", os.environ.get("REDIS_SSL", "False")
        ).lower()
        == "true",
    },
}
# Cache timeout in seconds. Set to 0 to disable caching.
CACHE_TIMEOUT = int(os.environ.get("CACHE_TIMEOUT", 900))

DEBUG = os.environ.get("DEBUG", "False").lower() == "true"

EMAIL = {
    "SERVER": os.environ.get("EMAIL_SERVER", "localhost"),
    "PORT": int(os.environ.get("EMAIL_PORT", 25)),
    "USERNAME": os.environ.get("EMAIL_USERNAME", ""),
    "PASSWORD": os.environ.get("EMAIL_PASSWORD", read_secret("email_password")),
    "TIMEOUT": int(os.environ.get("EMAIL_TIMEOUT", 10)),  # seconds
    "FROM_ADDRESS": os.environ.get("EMAIL_FROM_ADDRESS", ""),
    "USE_SSL": os.environ.get("EMAIL_USE_SSL", "False").lower() == "true",
    "USE_TLS": os.environ.get("EMAIL_USE_TLS", "False").lower() == "true",
    "SSL_CERTFILE": os.environ.get("EMAIL_SSL_CERTFILE", ""),
    "SSL_KEYFILE": os.environ.get("EMAIL_SSL_KEYFILE", ""),
}

CHANGELOG_RETENTION = int(os.environ.get("CHANGELOG_RETENTION", 90))
LOGIN_REQUIRED = os.environ.get("LOGIN_REQUIRED", "False").lower() == "true"
PEERINGDB_USERNAME = os.environ.get("PEERINGDB_USERNAME", "")
PEERINGDB_PASSWORD = os.environ.get(
    "PEERINGDB_PASSWORD", read_secret("peeringdb_password")
)
NAPALM_USERNAME = os.environ.get("NAPALM_USERNAME", "")
NAPALM_PASSWORD = os.environ.get("NAPALM_PASSWORD", read_secret("napalm_password"))
NAPALM_TIMEOUT = int(os.environ.get("NAPALM_TIMEOUT", 30))
NAPALM_ARGS = dict([
  (var[len('NAPALM_ARG_'):].lower(), os.environ.get(var))
  for var in os.environ.keys() if var.startswith('NAPALM_ARG_')
])
PAGINATE_COUNT = int(os.environ.get("PAGINATE_COUNT", 50))
BGPQ3_PATH = os.environ.get("BGPQ3_PATH", "bgpq3")
BGPQ3_HOST = os.environ.get("BGPQ3_HOST", "rr.ntt.net")
BGPQ3_SOURCES = os.environ.get(
    "BGPQ3_SOURCES",
    "RIPE,APNIC,AFRINIC,ARIN,NTTCOM,ALTDB,BBOI,BELL,JPIRR,LEVEL3,RADB,RGNET,SAVVIS,TC",
)
BGPQ3_ARGS = {
    "ipv6": os.environ.get("BGPQ3_ARGS_IPV6", "-r 16 -R 48").split(" "),
    "ipv4": os.environ.get("BGPQ3_ARGS_IPV4", "-r 8 -R 24").split(" "),
}
NETBOX_API = os.environ.get("NETBOX_API", None)
NETBOX_API_TOKEN = os.environ.get("NETBOX_API_TOKEN", read_secret("netbox_api_token"))
NETBOX_DEVICE_ROLES = os.environ.get(
    "NETBOX_DEVICE_ROLES", "router,firewall,switch"
).split(",")
RELEASE_CHECK_URL = os.environ.get(
    "RELEASE_CHECK_URL",
    "https://api.github.com/repos/respawner/peering-manager/releases",
)
RELEASE_CHECK_TIMEOUT = os.environ.get("RELEASE_CHECK_TIMEOUT", 86400)
