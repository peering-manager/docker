import sys

from utils.enums import Color
from utils.models import Tag

from startup_script_utils import load_yaml

tags = load_yaml("/opt/peering-manager/initializers/tags.yml")
if not tags:
    sys.exit()

for params in tags:
    if "color" in params:
        color = params.pop("color")

        for color_tpl in Color.choices:
            if color in color_tpl:
                params["color"] = color_tpl[0]

    tag, created = Tag.objects.get_or_create(**params)

    if created:
        print(f"🎨 Created tag '{tag.name}'")
