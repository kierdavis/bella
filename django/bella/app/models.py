import datetime

from django.db import models


def generate_upload_path(instance, orig_filename):
  model_name = instance.__class__.__name__.lower()
  now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
  return f"uploads/{model_name}/{now}_{orig_filename}"


class Garment(models.Model):
  name = models.CharField(max_length=200)

  class Meta:
    verbose_name = "garment idea"

  def __str__(self):
    return self.name


class GarmentPicture(models.Model):
  garment = models.ForeignKey(Garment, on_delete=models.CASCADE, related_name="pictures")
  file = models.FileField(upload_to=generate_upload_path)

  def __str__(self):
    return f"{self.garment.name} : {self.file.name}"


class Outfit(models.Model):
  name = models.CharField(max_length=200)
  garments = models.ManyToManyField(Garment, blank=True, related_name="outfits")

  class Meta:
    verbose_name = "outfit idea"

  def __str__(self):
    return self.name


class OutfitPicture(models.Model):
  outfit = models.ForeignKey(Outfit, on_delete=models.CASCADE, related_name="pictures")
  file = models.FileField(upload_to=generate_upload_path)

  def __str__(self):
    return f"{self.outfit.name} : {self.file.name}"


class Shop(models.Model):
  name = models.CharField(max_length=100)
  url = models.URLField(max_length=1000, blank=True)

  def __str__(self):
    return self.name


class Product(models.Model):
  name = models.CharField(max_length=100)
  shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name="products")
  url = models.URLField(max_length=1000, blank=True)
  garment = models.ForeignKey(
    Garment, blank=True, null=True, on_delete=models.SET_NULL, related_name="products"
  )

  def __str__(self):
    return f"{self.shop.name} : {self.name}"
