## Generic Parts
# These functions are providing the functionality to load
# arbitrary configuration files.
#
# They can be imported by other code (see `ldap_config.py` for an example).

import importlib.util
import sys
from pathlib import Path
from types import ModuleType


def _import(
    module_name: str, path: Path, loaded_configurations: list[ModuleType]
) -> None:
    spec = importlib.util.spec_from_file_location("", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.modules[module_name] = module

    loaded_configurations.insert(0, module)

    print(f"⚙️  Loaded config '{path}'")


def read_configurations(
    config_module: str, config_dir: str, main_config: str
) -> list[ModuleType]:
    loaded_configurations = []

    main_config_path = Path(config_dir, f"{main_config}.py").resolve()
    if main_config_path.is_file():
        _import(
            f"{config_module}.{main_config}", main_config_path, loaded_configurations
        )
    else:
        print(f"✖️ Main configuration '{main_config_path}' not found.")

    for f in main_config_path.parent.glob("*.py"):
        if (
            not f.is_file()
            or f.name.startswith("__")
            or f.name in (f"{main_config}.py", f"{config_dir}.py")
        ):
            continue

        module_name = f"{config_module}.{f.name[:-len('.py')]}".replace(".", "_")
        _import(module_name, f, loaded_configurations)

    if len(loaded_configurations) == 0:
        print(f"⚠️  No configuration files found in '{config_dir}'.")
        raise ImportError(f"No configuration files found in '{config_dir}'.")

    return loaded_configurations


## Specific Parts
# This section's code actually loads the various configuration files
# into the module with the given name.
# It contains the logic to resolve arbitrary configuration options by
# levaraging dynamic programming using `__getattr__`.


_loaded_configurations = read_configurations(
    config_dir="/etc/peering-manager/config/",
    config_module="peering_manager.configuration",
    main_config="configuration",
)


def __getattr__(name):
    for config in _loaded_configurations:
        try:
            return getattr(config, name)
        except Exception:
            pass
    raise AttributeError


def __dir__():
    names = []
    for config in _loaded_configurations:
        names.extend(config.__dir__())
    return names
