# Generated by Django 2.2.16 on 2020-11-22 01:11
from django.db import migrations
from django.db import models


class Migration(migrations.Migration):

  initial = True

  dependencies = []

  operations = [
    migrations.CreateModel(
      name="Garment",
      fields=[
        (
          "id",
          models.AutoField(
            auto_created=True, primary_key=True, serialize=False, verbose_name="ID",
          ),
        ),
        ("name", models.CharField(max_length=200)),
      ],
    ),
  ]
