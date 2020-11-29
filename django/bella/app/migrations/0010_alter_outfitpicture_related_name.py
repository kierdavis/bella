# Generated by Django 3.2 on 2020-11-23 00:50
import django.db.models.deletion
from django.db import migrations
from django.db import models


class Migration(migrations.Migration):

  dependencies = [
    ("bella", "0009_alter_outfit_garment_relation_to_be_optional"),
  ]

  operations = [
    migrations.AlterField(
      model_name="outfitpicture",
      name="outfit",
      field=models.ForeignKey(
        on_delete=django.db.models.deletion.CASCADE, related_name="pictures", to="bella.outfit"
      ),
    ),
  ]
