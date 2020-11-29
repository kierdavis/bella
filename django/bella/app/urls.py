from django.urls import path

from . import views

urlpatterns = [
  path("", views.index, name="index"),
  path("garments", views.GarmentsView.as_view(), name="garments"),
  path("garments/new", views.GarmentView.as_view(), name="new_garment"),
  path("garments/<int:obj_id>", views.GarmentView.as_view(), name="garment"),
  path("outfits", views.OutfitsView.as_view(), name="outfits"),
  path("outfits/new", views.OutfitView.as_view(), name="new_outfit"),
  path("outfits/<int:obj_id>", views.OutfitView.as_view(), name="outfit"),
]
