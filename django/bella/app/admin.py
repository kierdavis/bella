from django.contrib import admin

from .models import Garment
from .models import GarmentPicture
from .models import Outfit
from .models import OutfitPicture
from .models import Product
from .models import Shop

admin.site.register(Garment)
admin.site.register(GarmentPicture)
admin.site.register(Outfit)
admin.site.register(OutfitPicture)
admin.site.register(Shop)
admin.site.register(Product)
