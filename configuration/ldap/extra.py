####
## This file contains extra configuration options that can't be configured
## directly through environment variables.
## All vairables set here overwrite any existing found in ldap_config.py
####

# # This Python script inherits all the imports from ldap_config.py
# from django_auth_ldap.config import LDAPGroupQuery # Imported since not in ldap_config.py

# # Sets a base requirement of membetship to peeringmanager-user-ro, peeringmanager-user-rw, or peeringmanager-user-admin.
# AUTH_LDAP_REQUIRE_GROUP = (
#     LDAPGroupQuery("cn=peeringmanager-user-ro,ou=groups,dc=example,dc=com")
#     | LDAPGroupQuery("cn=peeringmanager-user-rw,ou=groups,dc=example,dc=com")
#     | LDAPGroupQuery("cn=peeringmanager-user-admin,ou=groups,dc=example,dc=com")
# )

# # Sets LDAP Flag groups variables with example.
# AUTH_LDAP_USER_FLAGS_BY_GROUP = {
#     "is_staff": (
#         LDAPGroupQuery("cn=peeringmanager-user-ro,ou=groups,dc=example,dc=com")
#         | LDAPGroupQuery("cn=peeringmanager-user-rw,ou=groups,dc=example,dc=com")
#         | LDAPGroupQuery("cn=peeringmanager-user-admin,ou=groups,dc=example,dc=com")
#     ),
#     "is_superuser": "cn=peeringmanager-user-admin,ou=groups,dc=example,dc=com",
# }

# # Sets LDAP Mirror groups variables with example groups
# AUTH_LDAP_MIRROR_GROUPS = ["peeringmanager-user-ro", "peeringmanager-user-rw", "peeringmanager-user-admin"]
