import json
import re
from os import environ
from typing import Any, Callable

# For reference see: https://docs.peering-manager.net/configuration/


# Read secret from file
def _read_secret(secret_name: str, default: str | None = None) -> str | None:
    try:
        f = open(f"/run/secrets/{secret_name}", encoding="utf-8")
    except EnvironmentError:
        return default
    else:
        with f:
            return f.readline().strip()


# If the `map_fn` isn't defined, then the value that is read from the environment (or
# the default value if not found) is returned.
# If the `map_fn` is defined, then `map_fn` is invoked and the value (that was read
# from the environment or the default value if not found) is passed to it as a
# parameter. The value returned from `map_fn` is then the return value of this
# function.
# The `map_fn` is not invoked, if the value (that was read from the environment or the
# default value if not found) is None.
def _environ_get_and_map(
    variable_name: str,
    default: str | None = None,
    map_fn: Callable[[str], Any | None] = None,
) -> Any | None:
    env_value = environ.get(variable_name, default)

    if env_value is None:
        return env_value

    if not map_fn:
        return env_value

    return map_fn(env_value)


def _AS_BOOL(value: str) -> bool:
    return value.lower() == "true"


def _AS_INT(value: str) -> int:
    return int(value)


def _AS_LIST(value: str) -> list[Any]:
    return list(filter(None, value.split(" ")))


def _AS_STRUCT(value: str) -> dict[Any, Any] | list[Any]:
    return json.loads(value)


# This is a list of valid fully-qualified domain names (FQDNs) for this server.
# The server will not permit write access to the server via any other
# hostnames. The first FQDN in the list will be treated as the preferred name.
#
# Example: ALLOWED_HOSTS = ["peering.example.com", "peering.internal.local"]
ALLOWED_HOSTS = environ.get("ALLOWED_HOSTS", "*").split(" ")
# ensure that "*" or "localhost" is always in ALLOWED_HOSTS (needed for health checks)
if "*" not in ALLOWED_HOSTS and "localhost" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("localhost")

# PostgreSQL database configuration. See the Django documentation for a complete list
# of available parameters:
#   https://docs.djangoproject.com/en/stable/ref/settings/#databases
DATABASE = {
    "NAME": environ.get("DB_NAME", "peering_manager"),
    "USER": environ.get("DB_USER", ""),
    "PASSWORD": _read_secret("db_password", environ.get("DB_PASSWORD", "")),
    "HOST": environ.get("DB_HOST", "localhost"),
    "PORT": environ.get("DB_PORT", ""),
    "OPTIONS": {"sslmode": environ.get("DB_SSLMODE", "prefer")},
    "CONN_MAX_AGE": _environ_get_and_map("DB_CONN_MAX_AGE", "300", _AS_INT),
    "DISABLE_SERVER_SIDE_CURSORS": _environ_get_and_map(
        "DB_DISABLE_SERVER_SIDE_CURSORS", "False", _AS_BOOL
    ),
}

# Redis database settings. Redis is used for caching and for queuing background tasks
# such as configuration rendering. A separate configuration exists for each. Full
# connection details are required in both sections, and it is strongly recommended to
# use two separate database IDs.
REDIS = {
    "tasks": {
        "HOST": environ.get("REDIS_HOST", "localhost"),
        "PORT": _environ_get_and_map("REDIS_PORT", 6379, _AS_INT),
        "SENTINELS": [
            tuple(uri.split(":"))
            for uri in _environ_get_and_map("REDIS_SENTINELS", "", _AS_LIST)
            if uri != ""
        ],
        "SENTINEL_SERVICE": environ.get("REDIS_SENTINEL_SERVICE", "default"),
        "SENTINEL_TIMEOUT": _environ_get_and_map("REDIS_SENTINEL_TIMEOUT", 10, _AS_INT),
        "USERNAME": environ.get("REDIS_USERNAME", ""),
        "PASSWORD": _read_secret("redis_password", environ.get("REDIS_PASSWORD", "")),
        "DATABASE": _environ_get_and_map("REDIS_DATABASE", "0", _AS_INT),
        "SSL": _environ_get_and_map("REDIS_SSL", "False", _AS_BOOL),
        "INSECURE_SKIP_TLS_VERIFY": _environ_get_and_map(
            "REDIS_INSECURE_SKIP_TLS_VERIFY", "False", _AS_BOOL
        ),
    },
    "caching": {
        "HOST": environ.get("REDIS_CACHE_HOST", environ.get("REDIS_HOST", "localhost")),
        "PORT": _environ_get_and_map(
            "REDIS_CACHE_PORT", environ.get("REDIS_PORT", "6379"), _AS_INT
        ),
        "SENTINELS": [
            tuple(uri.split(":"))
            for uri in _environ_get_and_map("REDIS_CACHE_SENTINELS", "", _AS_LIST)
            if uri != ""
        ],
        "SENTINEL_SERVICE": environ.get(
            "REDIS_CACHE_SENTINEL_SERVICE",
            environ.get("REDIS_SENTINEL_SERVICE", "default"),
        ),
        "USERNAME": environ.get(
            "REDIS_CACHE_USERNAME", environ.get("REDIS_USERNAME", "")
        ),
        "PASSWORD": _read_secret(
            "redis_cache_password",
            environ.get("REDIS_CACHE_PASSWORD", environ.get("REDIS_PASSWORD", "")),
        ),
        "DATABASE": _environ_get_and_map("REDIS_CACHE_DATABASE", "1", _AS_INT),
        "SSL": _environ_get_and_map(
            "REDIS_CACHE_SSL", environ.get("REDIS_SSL", "False"), _AS_BOOL
        ),
        "INSECURE_SKIP_TLS_VERIFY": _environ_get_and_map(
            "REDIS_CACHE_INSECURE_SKIP_TLS_VERIFY",
            environ.get("REDIS_INSECURE_SKIP_TLS_VERIFY", "False"),
            _AS_BOOL,
        ),
    },
}

# This key is used for secure generation of random numbers and strings. It must never
# be exposed outside of this file. For optimal security, SECRET_KEY should be at least
# 50 characters in length and contain a mix of letters, numbers, and symbols. Peering
# Manager will not run without this defined. For more information, see
# https://docs.djangoproject.com/en/stable/ref/settings/#std:setting-SECRET_KEY
SECRET_KEY = _read_secret("secret_key", environ.get("SECRET_KEY", ""))

#########################
#                       #
#   Optional settings   #
#                       #
#########################

# Specify one or more name and email address tuples representing Peering Manager
# administrators. These people will be notified of application errors (assuming
# correct email settings are provided).
if "ADMINS" in environ:
    ADMINS = _environ_get_and_map("ADMINS", "[]", _AS_STRUCT)

# Maximum number of days to retain logged changes. Set to 0 to retain changes
# indefinitely. (Default: 90)
if "CHANGELOG_RETENTION" in environ:
    CHANGELOG_RETENTION = _environ_get_and_map("CHANGELOG_RETENTION", None, _AS_INT)

# Maximum number of days to retain job results. Set to 0 to retain job results in the
# database indefinitely. (Default: 90)
if "JOB_RETENTION" in environ:
    JOB_RETENTION = _environ_get_and_map("JOB_RETENTION", None, _AS_INT)
# JOBRESULT_RETENTION was renamed to JOB_RETENTION in the v1.8.0 release of Peering
# Manager. For backwards compatibility, map JOBRESULT_RETENTION to JOB_RETENTION
elif "JOBRESULT_RETENTION" in environ:
    JOB_RETENTION = _environ_get_and_map("JOBRESULT_RETENTION", None, _AS_INT)

# API Cross-Origin Resource Sharing (CORS) settings. If CORS_ORIGIN_ALLOW_ALL is set
# to True, all origins will be allowed. Otherwise, define a list of allowed origins
# using either CORS_ORIGIN_WHITELIST or CORS_ORIGIN_REGEX_WHITELIST. For more
# information, see https://github.com/ottoyiu/django-cors-headers
CORS_ORIGIN_ALLOW_ALL = _environ_get_and_map("CORS_ORIGIN_ALLOW_ALL", "False", _AS_BOOL)
CORS_ORIGIN_WHITELIST = _environ_get_and_map(
    "CORS_ORIGIN_WHITELIST", "https://localhost", _AS_LIST
)
CORS_ORIGIN_REGEX_WHITELIST = [
    re.compile(r)
    for r in _environ_get_and_map("CORS_ORIGIN_REGEX_WHITELIST", "", _AS_LIST)
]

# Set to True to enable server debugging. WARNING: Debugging introduces a substantial
# performance penalty and may reveal sensitive information about your installation.
# Only enable debugging while performing testing. Never enable debugging on a
# production system.
DEBUG = _environ_get_and_map("DEBUG", "False", _AS_BOOL)

# Email settings
EMAIL = {
    "SERVER": environ.get("EMAIL_SERVER", "localhost"),
    "PORT": _environ_get_and_map("EMAIL_PORT", "25", _AS_INT),
    "USERNAME": environ.get("EMAIL_USERNAME", ""),
    "PASSWORD": _read_secret("email_password", environ.get("EMAIL_PASSWORD", "")),
    "USE_SSL": _environ_get_and_map("EMAIL_USE_SSL", "False", _AS_BOOL),
    "USE_TLS": _environ_get_and_map("EMAIL_USE_TLS", "False", _AS_BOOL),
    "SSL_CERTFILE": environ.get("EMAIL_SSL_CERTFILE", ""),
    "SSL_KEYFILE": environ.get("EMAIL_SSL_KEYFILE", ""),
    "TIMEOUT": _environ_get_and_map("EMAIL_TIMEOUT", "10", _AS_INT),  # seconds
    "FROM_EMAIL": environ.get("EMAIL_FROM_ADDRESS", ""),
    "EMAIL_CC_CONTACTS": _environ_get_and_map("EMAIL_CC_CONTACTS", "[]", _AS_STRUCT),
}

# By default, Peering Manager sends census reporting data using a single HTTP request
# each time a worker starts. This data enables the project maintainers to estimate how
# many Peering Manager deployments exist and track the adoption of new versions over
# time. The only data reported by this function are the Peering Manager version,
# Python version, and a pseudorandom unique identifier. To opt out of census
# reporting, set CENSUS_REPORTING_ENABLED to False.
if "CENSUS_REPORTING_ENABLED" in environ:
    CENSUS_REPORTING_ENABLED = _environ_get_and_map(
        "CENSUS_REPORTING_ENABLED", None, _AS_BOOL
    )

# HTTP proxies Peering Manager should use when sending outbound HTTP requests (e.g.
# for reaching PeeringDB).
HTTP_PROXIES = {
    "http": environ.get("HTTP_PROXY", None),
    "https": environ.get("HTTPS_PROXY", None),
}

# IP addresses recognized as internal to the system. The debugging toolbar will be
# available only to clients accessing Peering Manager from an internal IP.
INTERNAL_IPS = _environ_get_and_map("INTERNAL_IPS", "127.0.0.1 ::1", _AS_LIST)

# Enable custom logging. Please see the Django documentation for detailed guidance
# on configuring custom logs:
#   https://docs.djangoproject.com/en/stable/topics/logging/
# LOGGING = {}

# Automatically reset the lifetime of a valid session upon each authenticated request.
# Enables users to remain authenticated to Peering Manager indefinitely.
LOGIN_PERSISTENCE = _environ_get_and_map("LOGIN_PERSISTENCE", "False", _AS_BOOL)

# When enabled, only authenticated users are permitted to access any part of Peering
# Manager. Disabling this will allow unauthenticated users to access most areas of
# Peering Manager (but not make any changes).
LOGIN_REQUIRED = _environ_get_and_map("LOGIN_REQUIRED", "True", _AS_BOOL)

# The length of time (in seconds) for which a user will remain logged into the web UI
# before being prompted to re-authenticate. (Default: 1209600 [14 days])
LOGIN_TIMEOUT = _environ_get_and_map("LOGIN_TIMEOUT", "1209600", _AS_INT)

# An API consumer can request an arbitrary number of objects =by appending the "limit"
# parameter to the URL (e.g. "?limit=1000"). This setting defines the maximum limit.
# Setting it to 0 or None will allow an API consumer to request all objects by
# specifying "?limit=0".
if "MAX_PAGE_SIZE" in environ:
    MAX_PAGE_SIZE = _environ_get_and_map("MAX_PAGE_SIZE", None, _AS_INT)

# Expose Prometheus monitoring metrics at the HTTP endpoint '/metrics'
METRICS_ENABLED = _environ_get_and_map("METRICS_ENABLED", "False", _AS_BOOL)

# Determine how many objects to display per page within a list. (Default: 50)
if "PAGINATE_COUNT" in environ:
    PAGINATE_COUNT = _environ_get_and_map("PAGINATE_COUNT", None, _AS_INT)

# Remote authentication support
REMOTE_AUTH_ENABLED = _environ_get_and_map("REMOTE_AUTH_ENABLED", "False", _AS_BOOL)
REMOTE_AUTH_AUTO_CREATE_GROUPS = _environ_get_and_map(
    "REMOTE_AUTH_AUTO_CREATE_GROUPS", "False", _AS_BOOL
)
REMOTE_AUTH_AUTO_CREATE_USER = _environ_get_and_map(
    "REMOTE_AUTH_AUTO_CREATE_USER", "False", _AS_BOOL
)
REMOTE_AUTH_BACKEND = _environ_get_and_map(
    "REMOTE_AUTH_BACKEND", "peering_manager.authentication.RemoteUserBackend", _AS_LIST
)
REMOTE_AUTH_DEFAULT_GROUPS = _environ_get_and_map(
    "REMOTE_AUTH_DEFAULT_GROUPS", "", _AS_LIST
)
REMOTE_AUTH_DEFAULT_PERMISSIONS = _environ_get_and_map(
    "REMOTE_AUTH_DEFAULT_PERMISSIONS", "", _AS_LIST
)
REMOTE_AUTH_GROUP_HEADER = _environ_get_and_map(
    "REMOTE_AUTH_GROUP_HEADER", "HTTP_REMOTE_USER_GROUP"
)
REMOTE_AUTH_GROUP_SEPARATOR = _environ_get_and_map("REMOTE_AUTH_GROUP_SEPARATOR", "|")
REMOTE_AUTH_GROUP_SYNC_ENABLED = _environ_get_and_map(
    "REMOTE_AUTH_GROUP_SYNC_ENABLED", "False", _AS_BOOL
)
REMOTE_AUTH_HEADER = environ.get("REMOTE_AUTH_HEADER", "HTTP_REMOTE_USER")
REMOTE_AUTH_USER_EMAIL = environ.get("REMOTE_AUTH_USER_EMAIL", "HTTP_REMOTE_USER_EMAIL")
REMOTE_AUTH_USER_FIRST_NAME = environ.get(
    "REMOTE_AUTH_USER_FIRST_NAME", "HTTP_REMOTE_USER_FIRST_NAME"
)
REMOTE_AUTH_USER_LAST_NAME = environ.get(
    "REMOTE_AUTH_USER_LAST_NAME", "HTTP_REMOTE_USER_LAST_NAME"
)
REMOTE_AUTH_SUPERUSER_GROUPS = _environ_get_and_map(
    "REMOTE_AUTH_SUPERUSER_GROUPS", "", _AS_LIST
)
REMOTE_AUTH_SUPERUSERS = _environ_get_and_map("REMOTE_AUTH_SUPERUSERS", "", _AS_LIST)
REMOTE_AUTH_STAFF_GROUPS = _environ_get_and_map(
    "REMOTE_AUTH_STAFF_GROUPS", "", _AS_LIST
)
REMOTE_AUTH_STAFF_USERS = _environ_get_and_map("REMOTE_AUTH_STAFF_USERS", "", _AS_LIST)

# This repository is used to check whether there is a new release of Peering Manager
# available. Set to None to disable the version check or use the URL below to check
# for release in the official Peering Manager repository.
RELEASE_CHECK_URL = environ.get("RELEASE_CHECK_URL", None)
# RELEASE_CHECK_URL = "https://api.github.com/repos/peering-manager/peering-manager/releases"

# Maximum execution time for background tasks, in seconds.
RQ_DEFAULT_TIMEOUT = _environ_get_and_map("RQ_DEFAULT_TIMEOUT", "300", _AS_INT)

# The name to use for the csrf token cookie.
CSRF_COOKIE_NAME = environ.get("CSRF_COOKIE_NAME", "csrftoken")

# Cross-Site-Request-Forgery-Attack settings. If Peering Manager is sitting behind a
# reverse proxy, you might need to set the CSRF_TRUSTED_ORIGINS flag. Django 4.0
# requires to specify the URL Scheme in this setting. An example environment variable
# could be specified like:
# CSRF_TRUSTED_ORIGINS=https://demo.peering-manager.net http://demo.peering-manager.net
CSRF_TRUSTED_ORIGINS = _environ_get_and_map("CSRF_TRUSTED_ORIGINS", "", _AS_LIST)

# The name to use for the session cookie.
SESSION_COOKIE_NAME = environ.get("SESSION_COOKIE_NAME", "sessionid")

# By default, Peering Manager will store session data in the database. Alternatively,
# a file path can be specified here to use local file storage instead. (This can be
# useful for enabling authentication on a standby instance with read-only database
# access.) Note that the user as which Peering Manager runs must have read and write
# permissions to this path.
SESSION_FILE_PATH = environ.get("SESSION_FILE_PATH", environ.get("SESSIONS_ROOT", None))

# Time zone (default: UTC)
TIME_ZONE = environ.get("TIME_ZONE", "UTC")

# Text to include on the login page above the login form. HTML is allowed.
if "BANNER_LOGIN" in environ:
    BANNER_LOGIN = environ.get("BANNER_LOGIN", None)

# PeeringDB API key used to authenticate against PeeringDB allowing Peering
# Manager to synchronise data not accessible without authentication (such as
# e-mail contacts).
PEERINGDB_API_KEY = _read_secret(
    "peeringdb_api_key", environ.get("PEERINGDB_API_KEY", "")
)


# Peering Manager will use these credentials when authenticating to remote devices via
# the NAPALM library
if "NAPALM_USERNAME" in environ:
    NAPALM_USERNAME = environ.get("NAPALM_USERNAME", "")
if "NAPALM_PASSWORD" in environ:
    NAPALM_PASSWORD = _read_secret(
        "napalm_password", environ.get("NAPALM_PASSWORD", "")
    )
if "NAPALM_TIMEOUT" in environ:
    NAPALM_TIMEOUT = _environ_get_and_map("NAPALM_TIMEOUT", "10", _AS_INT)
NAPALM_ARGS = dict(
    [
        (var[len("NAPALM_ARG_") :].lower(), environ.get(var))
        for var in environ.keys()
        if var.startswith("NAPALM_ARG_")
    ]
)

# The path to the bgpq3 or bgpq4 binary
if "BGPQ3_PATH" in environ:
    BGPQ3_PATH = environ.get("BGPQ3_PATH", "bgpq3")
if "BGPQ3_HOST" in environ:
    BGPQ3_HOST = environ.get("BGPQ3_HOST", "rr.ntt.net")
if "BGPQ3_SOURCES" in environ:
    BGPQ3_SOURCES = environ.get(
        "BGPQ3_SOURCES",
        "RPKI,RIPE,ARIN,APNIC,AFRINIC,LACNIC,RIPE-NONAUTH,RADB,ALTDB,NTTCOM,LEVEL3,TC",
    )
BGPQ3_ARGS = {
    "ipv6": _environ_get_and_map("BGPQ3_ARGS_IPV6", "-r 16 -R 48", _AS_LIST),
    "ipv4": _environ_get_and_map("BGPQ3_ARGS_IPV4", "-r 8 -R 24", _AS_LIST),
}

if "NETBOX_API" in environ:
    NETBOX_API = environ.get("NETBOX_API", "")
if "NETBOX_API_TOKEN" in environ:
    NETBOX_API_TOKEN = _read_secret(
        "netbox_api_token", environ.get("NETBOX_API_TOKEN", "")
    )
if "NETBOX_API_THREADING" in environ:
    NETBOX_API_THREADING = _environ_get_and_map(
        "NETBOX_API_THREADING", "False", _AS_BOOL
    )
if "NETBOX_API_VERIFY_SSL" in environ:
    NETBOX_API_VERIFY_SSL = _environ_get_and_map(
        "NETBOX_API_THREADING", "True", _AS_BOOL
    )
if "NETBOX_DEVICE_ROLES" in environ:
    NETBOX_DEVICE_ROLES = _environ_get_and_map(
        "NETBOX_DEVICE_ROLES", "router firewall", _AS_LIST
    )
if "NETBOX_TAGS" in environ:
    NETBOX_TAGS = _environ_get_and_map("NETBOX_TAGS", None, _AS_LIST)

# User agent that Peering Manager will use when making requests to external HTTP
# resources. It should not require to be changed unless you have issues with specific
# HTTP endpoints.
if "REQUESTS_USER_AGENT" in environ:
    REQUESTS_USER_AGENT = environ.get("REQUESTS_USER_AGENT", "")

# List of Jinja2 extensions to load when rendering templates. Extensions can
# be used to add more features to the initial ones. Extensions that are not
# built into Jinja2 need to be installed in the Python environment used to run
# Peering Manager.
if "JINJA2_TEMPLATE_EXTENSIONS" in environ:
    JINJA2_TEMPLATE_EXTENSIONS = _environ_get_and_map(
        "JINJA2_TEMPLATE_EXTENSIONS", "", _AS_LIST
    )

# Git commit author that will be used when committing changes in Git
# repositories when used as data sources. It must be compliant with the Git
# format.
if "GIT_COMMIT_AUTHOR" in environ:
    GIT_COMMIT_AUTHOR = environ.get(
        "GIT_COMMIT_AUTHOR", "Peering Manager <no-reply@peering-manager.net>"
    )

# Message to log in commits that will be performed using Peering Manager in
# Git repositories when used as data sources.
if "GIT_COMMIT_MESSAGE" in environ:
    GIT_COMMIT_MESSAGE = environ.get(
        "GIT_COMMIT_MESSAGE", "Committed using Peering Manager"
    )

# Perform validation of the value when creating or updating a BGP community
if "VALIDATE_BGP_COMMUNITY_VALUE" in environ:
    VALIDATE_BGP_COMMUNITY_VALUE = _environ_get_and_map(
        "VALIDATE_BGP_COMMUNITY_VALUE", "True", _AS_BOOL
    )

# When merging configuration contexts, Peering Manager needs to know what
# should happen to nested dictionaries/hashes and to list. These two options
# can be changed to reproduce the wanted behaviour. They are similar to
# Ansible's `combine` filter and should produce the same results.
CONFIG_CONTEXT_MERGE_STRATEGY = {
    "recursive": _environ_get_and_map("CONFIG_CONTEXT_RECURSIVE_MERGE", None, _AS_BOOL),
    "list_merge": environ.get("CONFIG_CONTEXT_LIST_MERGE", "replace"),
}
