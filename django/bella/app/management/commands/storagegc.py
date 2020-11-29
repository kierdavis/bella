from pathlib import PurePath

from django.apps import apps
from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand
from django.db.models import FileField


class Command(BaseCommand):
  help = "Remove storage objects that are no longer referenced by the database"

  def handle(self, *args, **kwargs):
    paths_in_storage = frozenset(self.paths_in_storage())
    paths_in_database = frozenset(self.paths_in_database())
    for path in paths_in_storage - paths_in_database:
      print(path)
      default_storage.delete(path)

  def paths_in_storage(self, root=PurePath()):
    dir_names, file_names = default_storage.listdir(str(root))
    for file_name in file_names:
      yield str(root / file_name)
    for dir_name in dir_names:
      yield from self.paths_in_storage(root / dir_name)

  def paths_in_database(self):
    for model in apps.all_models["bella"].values():
      for field in model._meta.fields:
        if isinstance(field, FileField):
          for obj in model.objects.only(field.attname):
            yield getattr(obj, field.attname).name
